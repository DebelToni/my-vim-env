-- opencode_copilot_chat.lua
-- A small floating “chat” UI for OpenCode, designed to complement /mnt/data/opencode_copilot.lua.
--
-- Features (matching your vision):
--   - <leader>co : open most recent session (captures buffer+cursor/selection context on open)
--   - <leader>cn : create + open a new session
--   - <leader>cl : fuzzy-pick previous sessions (Telescope if available, else vim.ui.select)
--   - In the floating chat buffer:
--       * Normal-mode <CR> sends the “hover answer” request (short reply)
--       * Normal-mode <leader>ci sends an “inline code suggestion” request
--       * Insert-mode <CR> keeps being newline (default)
--   - Hover replies are shown in a hover window anchored to the original cursor/selection
--   - Inline suggestions show “@Thinking…” on the target line, then a green-highlighted suggestion
--     and can be accepted with <leader>y while cursor is on suggested lines.
--
-- Notes:
--   - Uses the same OpenCode HTTP server endpoints as /mnt/data/opencode_copilot.lua.
--   - Inline UI borrows the “spinner/region highlight/extmark” style ideas from /mnt/data/AI.lua,
--     but is self-contained.

local M = {}

local uv = vim.uv or vim.loop

-- ===================== CONFIG =====================
M.config = {
	server_url = "http://127.0.0.1:4096",
	server_username = vim.env.OPENCODE_SERVER_USERNAME or "opencode",
	server_password = vim.env.OPENCODE_SERVER_PASSWORD,
	auto_start_server = false,
	server_start_cmd = { "opencode", "serve", "--hostname", "127.0.0.1", "--port", "4096" },

	provider_id = "openai",
	model_id = "gpt-5.1-codex-mini",
	agent = "build",
	reasoning_effort = "none",

	request_timeout_ms = 60000,
	poll_delay_ms = 200,
	health_cache_ms = 10000,

	-- Context
	max_buffer_chars = 140000,
	include_file_header = true,

	-- UI
	ui = {
		border = "rounded",
		width = 0.62, -- fraction of editor
		height = 0.42, -- fraction of editor
		row = 0.10, -- fraction of editor
		col = 0.19, -- fraction of editor
	},

	hover = {
		border = "rounded",
		max_width = 90,
		max_height = 22,
		timeout_ms = 15000,
	},

	inline = {
		thinking_text = "@Thinking…",
		thinking_hl = "OpenCodeInlineThinking",
		suggest_hl = "OpenCodeInlineSuggestion",
	},

	debug = false,
}

-- ===================== STATE =====================
local state = {
	config = nil,
	initialized = false,

	next_id = 1,
	sessions = {}, -- { [id] = session }
	order = {}, -- most-recent first: array of ids
	most_recent = nil,

	last_health_check_ms = 0,
	server_healthy = false,
	health_check_inflight = false,
	starting_server = false,
}

-- namespaces
local ns_marks = vim.api.nvim_create_namespace("OpenCodeChatMarks")
local ns_inline = vim.api.nvim_create_namespace("OpenCodeChatInline")

-- ===================== UTILS =====================
local function now_ms()
	return math.floor(uv.hrtime() / 1000000)
end

local function notify(msg, level)
	vim.schedule(function()
		vim.notify(msg, level or vim.log.levels.INFO, { title = "OpenCode Chat" })
	end)
end

local function debug_notify(msg)
	if state.config and state.config.debug then
		notify("[debug] " .. msg, vim.log.levels.INFO)
	end
end

local function json_encode(v)
	if vim.json and vim.json.encode then return vim.json.encode(v) end
	return vim.fn.json_encode(v)
end

local function json_decode(v)
	if vim.json and vim.json.decode then return vim.json.decode(v) end
	return vim.fn.json_decode(v)
end

local function termcodes(keys)
	return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function url_encode(value)
	if vim.uri_encode then return vim.uri_encode(value) end
	return (value:gsub("([^%w%-_%.~])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function tbl_deep_extend(dst, src)
	if type(src) ~= "table" then return dst end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			tbl_deep_extend(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

local function get_buf_path(bufnr)
	local p = vim.api.nvim_buf_get_name(bufnr)
	return (p ~= "" and p) or nil
end

local function detect_root(bufnr)
	local path = get_buf_path(bufnr)
	local start = path and vim.fs.dirname(path) or uv.cwd()
	if vim.fs and vim.fs.root then
		local root = vim.fs.root(start, { ".git", "opencode.json", ".opencode" })
		if root then return root end
	end
	return uv.cwd()
end

local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function split_lines(text)
	if text == "" then return { "" } end
	return vim.split(text, "\n", { plain = true })
end

local function trim(s)
	s = (s or ""):gsub("^%s+", "")
	s = s:gsub("%s+$", "")
	return s
end

local function strip_code_fences(s)
	if not s then return "" end
	s = s:gsub("^%s*```[%w_-]*%s*\n", "")
	s = s:gsub("\n%s*```%s*$", "")
	return s
end

local function set_default_hl()
	-- Light green background by default; link to DiffAdd so it matches your colorscheme.
	pcall(vim.api.nvim_set_hl, 0, state.config.inline.suggest_hl, { link = "DiffAdd", default = true })
	pcall(vim.api.nvim_set_hl, 0, state.config.inline.thinking_hl, { link = "Comment", default = true })
end

-- ===================== HTTP =====================
local function request(cmd, body, on_done, opts)
	opts = opts or {}
	local cfg = state.config
	if not vim.system then
		on_done(false, nil, "Your Neovim is too old (needs vim.system support)", 0)
		return nil
	end

	local curl = {
		"curl",
		"-sS",
		"-f",
		"-X",
		opts.method or "GET",
		"-H",
		"Content-Type: application/json",
		"--connect-timeout",
		"2",
		"--max-time",
		string.format("%.2f", cfg.request_timeout_ms / 1000),
	}

	if cfg.server_password and cfg.server_password ~= "" then
		table.insert(curl, "-u")
		table.insert(curl, string.format("%s:%s", cfg.server_username, cfg.server_password))
	end

	if body ~= nil then
		table.insert(curl, "-d")
		table.insert(curl, json_encode(body))
	end

	table.insert(curl, cfg.server_url .. cmd)

	return vim.system(curl, { text = true }, function(obj)
		local stdout = obj.stdout or ""
		local stderr = obj.stderr or ""
		local status = tonumber(stderr:match(" (%d%d%d)")) or 0

		if obj.code ~= 0 then
			vim.schedule(function()
				on_done(false, nil, stderr ~= "" and stderr or ("curl exited " .. tostring(obj.code)), status)
			end)
			return
		end

		if stdout == "" then
			vim.schedule(function() on_done(true, {}, nil, 200) end)
			return
		end

		local ok, parsed = pcall(json_decode, stdout)
		if not ok then
			vim.schedule(function() on_done(false, nil, "Failed to parse server JSON", 0) end)
			return
		end

		vim.schedule(function() on_done(true, parsed, nil, 200) end)
	end)
end

local function ensure_server(cb)
	local cfg = state.config
	local now = now_ms()

	if state.server_healthy and (now - state.last_health_check_ms) < cfg.health_cache_ms then
		cb(true)
		return
	end

	if state.health_check_inflight then
		cb(state.server_healthy)
		return
	end

	state.health_check_inflight = true
	request("/global/health", nil, function(ok)
		state.health_check_inflight = false
		state.last_health_check_ms = now_ms()
		state.server_healthy = ok
		if ok then
			cb(true)
			return
		end

		if not cfg.auto_start_server or state.starting_server then
			cb(false)
			return
		end

		state.starting_server = true
		vim.system(cfg.server_start_cmd, { detach = true }, function()
			vim.schedule(function()
				vim.defer_fn(function()
					state.starting_server = false
					state.server_healthy = false
					state.last_health_check_ms = 0
					ensure_server(cb)
				end, 800)
			end)
		end)
	end)
end

-- ===================== OPENCODE SESSIONS =====================
local function seed_server_session(session, cb)
	if session.server_seeded or not session.server_session_id then
		cb(true)
		return
	end

	local seed = {
		noReply = true,
		parts = {
			{
				type = "text",
				text = table.concat({
					"Session role: Neovim Copilot Chat.",
					"You will receive full buffer context and a question.",
					"For hover replies: be concise and practical.",
					"For inline code replies: return ONLY code with no fences unless asked.",
				}, "\n"),
			},
		},
	}

	local endpoint = string.format("/session/%s/message?directory=%s", session.server_session_id,
		url_encode(session.root))
	request(endpoint, seed, function(ok)
		session.server_seeded = ok
		cb(ok)
	end, { method = "POST" })
end

local function create_server_session(root, title, cb)
	local endpoint = "/session?directory=" .. url_encode(root)
	request(endpoint, { title = title or "Neovim Copilot Chat" }, function(ok, data)
		if not ok or type(data) ~= "table" or type(data.id) ~= "string" then
			cb(false, nil)
			return
		end
		cb(true, data.id)
	end, { method = "POST" })
end

-- ===================== CONTEXT CAPTURE =====================
local function get_visual_selection(bufnr)
	local mode = vim.fn.mode()
	if not mode:match("^[vV\022]") then
		return nil
	end

	local vmode = vim.fn.visualmode() -- 'v', 'V', or Ctrl-V
	local p1 = vim.fn.getpos("'<")
	local p2 = vim.fn.getpos("'>")

	local sr, sc = p1[2] - 1, p1[3] - 1
	local er, ec = p2[2] - 1, p2[3] - 1
	if sr > er or (sr == er and sc > ec) then
		sr, er = er, sr
		sc, ec = ec, sc
	end

	if vmode == "V" then
		sc = 0
		local last = vim.api.nvim_buf_get_lines(bufnr, er, er + 1, false)[1] or ""
		ec = #last
	else
		-- charwise: make end col exclusive
		ec = ec + 1
	end

	local ok, text = pcall(vim.api.nvim_buf_get_text, bufnr, sr, sc, er, ec, {})
	local joined = ok and table.concat(text, "\n") or ""

	return {
		mode = vmode,
		sr = sr,
		sc = sc,
		er = er,
		ec = ec,
		text = joined,
	}
end

local function capture_open_context()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].buftype ~= "" then
		return nil, "unsupported buftype: " .. vim.bo[bufnr].buftype
	end
	local win = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(win)
	local row, col = cursor[1] - 1, cursor[2]
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count < 1 then
		line_count = 1
	end
	row = clamp(row, 0, line_count - 1)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	col = clamp(col, 0, #line)

	local sel = get_visual_selection(bufnr)
	local path = get_buf_path(bufnr) or "[No Name]"

	if sel then
		sel.sr = clamp(sel.sr, 0, line_count - 1)
		sel.er = clamp(sel.er, 0, line_count - 1)
		local sline = vim.api.nvim_buf_get_lines(bufnr, sel.sr, sel.sr + 1, false)[1] or ""
		local eline = vim.api.nvim_buf_get_lines(bufnr, sel.er, sel.er + 1, false)[1] or ""
		sel.sc = clamp(sel.sc, 0, #sline)
		sel.ec = clamp(sel.ec, 0, #eline)
	end

	-- Create extmarks to anchor hover/inline back to the original place, even if edits happen.
	-- For selection we store start+end; for cursor we store a single mark.
	local cursor_mark = vim.api.nvim_buf_set_extmark(bufnr, ns_marks, row, col, {
		right_gravity = true,
	})

	local sel_start_mark, sel_end_mark
	if sel then
		sel_start_mark = vim.api.nvim_buf_set_extmark(bufnr, ns_marks, sel.sr, sel.sc, { right_gravity = false })
		sel_end_mark = vim.api.nvim_buf_set_extmark(bufnr, ns_marks, sel.er, sel.ec, { right_gravity = true })
	end

	-- exit visual mode cleanly (so the chat window opens in normal mode)
	if sel then
		vim.api.nvim_feedkeys(termcodes("<Esc>"), "n", false)
	end

	return {
		bufnr = bufnr,
		winid = win,
		path = path,
		filetype = vim.bo[bufnr].filetype,
		root = detect_root(bufnr),
		cursor_mark = cursor_mark,
		sel = sel,
		sel_start_mark = sel_start_mark,
		sel_end_mark = sel_end_mark,
	}, nil
end

local function get_mark_pos(bufnr, mark_id)
	if not mark_id then return nil end
	local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_marks, mark_id, {})
	if not pos or #pos < 2 then return nil end
	return { pos[1], pos[2] }
end

local function build_buffer_context(ctx)
	local bufnr = ctx.bufnr
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local text = table.concat(lines, "\n")
	if #text > state.config.max_buffer_chars then
		-- Best effort: keep the whole buffer *up to max chars*.
		text = text:sub(1, state.config.max_buffer_chars)
		text = text .. "\n\n[... truncated by OpenCode Chat max_buffer_chars ...]"
	end

	local cur = get_mark_pos(bufnr, ctx.cursor_mark) or { 0, 0 }
	local header = {}
	if state.config.include_file_header then
		table.insert(header, string.format("File: %s", ctx.path))
		table.insert(header, string.format("Filetype: %s", (ctx.filetype ~= "" and ctx.filetype) or "plain"))
	end

	if ctx.sel then
		local s = get_mark_pos(bufnr, ctx.sel_start_mark) or { ctx.sel.sr, ctx.sel.sc }
		local e = get_mark_pos(bufnr, ctx.sel_end_mark) or { ctx.sel.er, ctx.sel.ec }
		table.insert(header, string.format("Selection: (%d:%d) -> (%d:%d)", s[1] + 1, s[2] + 1, e[1] + 1, e[2] + 1))
		table.insert(header, "Selected text:\n" .. ctx.sel.text)
	else
		table.insert(header, string.format("Cursor: line %d, col %d", cur[1] + 1, cur[2] + 1))
	end

	return table.concat(header, "\n") .. "\n\n<BUFFER>\n" .. text .. "\n</BUFFER>"
end

-- ===================== CHAT BUFFER UI =====================
local function chat_template(session)
	local lines = {
		string.format("# OpenCode Copilot Chat (Session %d)", session.id),
		string.format("# %s", session.ctx.path),
		"",
		"## History",
		"",
		"## Draft",
		">> ",
		"",
		"(Normal-mode <CR> = send hover reply; normal-mode <leader>ci = send inline suggestion; q = close)",
	}
	return lines
end

local function ensure_chat_buf(session)
	if session.chat_bufnr and vim.api.nvim_buf_is_valid(session.chat_bufnr) then
		return session.chat_bufnr
	end
	local bufnr = vim.api.nvim_create_buf(false, true)
	session.chat_bufnr = bufnr

	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, chat_template(session))

	return bufnr
end

local function find_section(bufnr, header)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for i, l in ipairs(lines) do
		if l == header then return i - 1 end -- 0-based
	end
	return nil
end

local function get_draft(bufnr)
	local draft_line = find_section(bufnr, "## Draft")
	if not draft_line then return "", nil, nil end
	local start = draft_line + 1
	local lines = vim.api.nvim_buf_get_lines(bufnr, start, -1, false)
	if #lines == 0 then return "", start, start end

	-- Stop at the first help line marker if present.
	local stop = #lines
	for i, l in ipairs(lines) do
		if l:match("^%(%s*Normal%-mode") then
			stop = i - 1
			break
		end
	end

	local draft_lines = {}
	for i = 1, stop do
		table.insert(draft_lines, lines[i])
	end

	if #draft_lines > 0 then
		draft_lines[1] = draft_lines[1]:gsub("^>>%s?", "")
	end

	local text = trim(table.concat(draft_lines, "\n"))
	return text, start, start + stop
end

local function set_draft(bufnr, new_text)
	local _, start, stop = get_draft(bufnr)
	if not start then return end
	local lines = split_lines(new_text or "")
	if #lines == 0 then lines = { "" } end
	lines[1] = ">> " .. lines[1]
	vim.api.nvim_buf_set_lines(bufnr, start, stop, false, lines)
end

local function append_history(bufnr, who, text)
	local hist_line = find_section(bufnr, "## History")
	local draft_line = find_section(bufnr, "## Draft")
	if not hist_line or not draft_line then return end

	local insert_at = draft_line -- insert right before Draft
	local block = {}
	table.insert(block, string.format("### %s", who))
	for _, l in ipairs(split_lines(text or "")) do
		table.insert(block, l)
	end
	table.insert(block, "")

	vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, block)

	-- return the start row (0-based) of the inserted block for later updates
	return insert_at
end

local function update_history_block(bufnr, block_start_row, new_text)
	if not block_start_row then return end
	if not vim.api.nvim_buf_is_valid(bufnr) then return end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if block_start_row < 0 or block_start_row >= #lines then return end

	-- Content begins after the "### ..." header and runs until the first blank line.
	local start = block_start_row + 1
	local stop = start
	while stop < #lines do
		if lines[stop + 1] == "" then break end
		stop = stop + 1
	end

	local new_lines = split_lines(new_text or "")
	vim.api.nvim_buf_set_lines(bufnr, start, stop + 1, false, new_lines)
end

local function open_float(bufnr)
	local cfg = state.config.ui
	local columns = vim.o.columns
	local lines = vim.o.lines

	local width = clamp(math.floor(columns * cfg.width), 40, columns - 4)
	local height = clamp(math.floor(lines * cfg.height), 10, lines - 4)
	local row = clamp(math.floor(lines * cfg.row), 0, lines - height - 1)
	local col = clamp(math.floor(columns * cfg.col), 0, columns - width)

	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		style = "minimal",
		border = cfg.border,
		row = row,
		col = col,
		width = width,
		height = height,
	})

	vim.wo[win].wrap = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = true
	return win
end

-- ===================== HOVER UI =====================
local function hover_at_mark(ctx, text)
	local bufnr = ctx.bufnr
	local pos = ctx.sel and get_mark_pos(bufnr, ctx.sel_start_mark) or get_mark_pos(bufnr, ctx.cursor_mark)
	pos = pos or { 0, 0 }

	-- Find a window showing this buffer; prefer original.
	local target_win = (ctx.winid and vim.api.nvim_win_is_valid(ctx.winid) and vim.api.nvim_win_get_buf(ctx.winid) == bufnr)
		and ctx.winid
		or nil

	if not target_win then
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_buf(w) == bufnr then
				target_win = w
				break
			end
		end
	end

	local row, col
	if target_win then
		local sp = vim.fn.screenpos(target_win, pos[1] + 1, pos[2] + 1)
		if sp and sp.row and sp.col and sp.row > 0 and sp.col > 0 then
			row = sp.row - 1
			col = sp.col - 1
		end
	end

	-- If we can't compute a position (buffer not visible), fall back near current cursor.
	local opts = {
		relative = "cursor",
		row = 1,
		col = 0,
		style = "minimal",
		border = state.config.hover.border,
	}
	if row and col then
		opts.relative = "editor"
		opts.row = row
		opts.col = col
	end

	local float_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[float_buf].buftype = "nofile"
	vim.bo[float_buf].bufhidden = "wipe"
	vim.bo[float_buf].swapfile = false
	vim.bo[float_buf].filetype = "markdown"

	local lns = split_lines(text or "")
	vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, lns)

	-- measure width/height
	local maxw = 1
	for _, l in ipairs(lns) do
		maxw = math.max(maxw, vim.fn.strdisplaywidth(l))
	end
	local width = clamp(maxw + 2, 20, state.config.hover.max_width)
	local height = clamp(#lns, 1, state.config.hover.max_height)
	opts.width, opts.height = width, height

	local win = vim.api.nvim_open_win(float_buf, false, opts)
	vim.wo[win].wrap = true
	vim.wo[win].conceallevel = 0

	-- Auto-close
	if state.config.hover.timeout_ms and state.config.hover.timeout_ms > 0 then
		local t = uv.new_timer()
		t:start(state.config.hover.timeout_ms, 0, function()
			vim.schedule(function()
				if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
				if t and not t:is_closing() then
					pcall(t.stop, t)
					pcall(t.close, t)
				end
			end)
		end)
	end
end

-- ===================== INLINE SUGGESTION UI =====================
local inline_state = {
	-- [bufnr] = { start_mark = id, end_mark = id, extmark = id, code = "...", lines = {...} }
	active = {},
}

local function clear_inline(bufnr)
	inline_state.active[bufnr] = nil
	if vim.api.nvim_buf_is_valid(bufnr) then
		pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns_inline, 0, -1)
	end
end

local function set_inline_thinking(bufnr, row)
	vim.api.nvim_buf_clear_namespace(bufnr, ns_inline, 0, -1)
	return vim.api.nvim_buf_set_extmark(bufnr, ns_inline, row, 0, {
		virt_text = { { state.config.inline.thinking_text, state.config.inline.thinking_hl } },
		virt_text_pos = "overlay",
		hl_mode = "combine",
	})
end

local function show_inline_suggestion(bufnr, row, code)
	code = strip_code_fences((code or ""):gsub("\r\n", "\n"):gsub("\r", "\n"))
	local lines = split_lines(code)

	vim.api.nvim_buf_clear_namespace(bufnr, ns_inline, 0, -1)
	local virt_lines = {}
	for _, l in ipairs(lines) do
		table.insert(virt_lines, { { l, state.config.inline.suggest_hl } })
	end

	local extmark = vim.api.nvim_buf_set_extmark(bufnr, ns_inline, row, 0, {
		virt_lines = virt_lines,
		virt_lines_above = false,
		hl_mode = "combine",
	})

	return extmark, lines
end

function M.accept_inline()
	local bufnr = vim.api.nvim_get_current_buf()
	local st = inline_state.active[bufnr]
	if not st then return false end

	local cur = vim.api.nvim_win_get_cursor(0)
	local crow = cur[1] - 1

	local start_pos = get_mark_pos(bufnr, st.start_mark) or { st.row, 0 }
	local end_pos = st.end_mark and get_mark_pos(bufnr, st.end_mark) or nil

	-- Only accept if cursor is on/near the suggestion block.
	local suggest_rows = #st.lines
	if crow < start_pos[1] or crow > (start_pos[1] + math.max(suggest_rows - 1, 0)) then
		return false
	end

	local insert_lines = st.lines
	vim.api.nvim_buf_call(bufnr, function()
		-- preserve undo
		pcall(vim.cmd, "silent! undojoin")

		if end_pos then
			vim.api.nvim_buf_set_text(bufnr, start_pos[1], start_pos[2], end_pos[1], end_pos[2], insert_lines)
		else
			vim.api.nvim_buf_set_text(bufnr, start_pos[1], start_pos[2], start_pos[1], start_pos[2], insert_lines)
		end
	end)

	clear_inline(bufnr)
	return true
end

local function attach_accept_keymap(bufnr)
	-- buffer-local so we don't hijack your global <leader>y
	vim.keymap.set("n", "<leader>y", function()
		M.accept_inline()
	end, { buffer = bufnr, silent = true, desc = "Accept OpenCode inline suggestion" })
end

-- ===================== PROMPTS =====================
local function build_hover_prompt(session, user_question)
	local ctx = build_buffer_context(session.ctx)
	return table.concat({
		"You are an expert coding assistant.",
		"Reply briefly and concretely. Prefer actionable steps or a short explanation.",
		"If code is necessary, keep it minimal and scoped.",
		"",
		"<CONTEXT>",
		ctx,
		"</CONTEXT>",
		"",
		"<QUESTION>",
		user_question,
		"</QUESTION>",
	}, "\n")
end

local function build_inline_prompt(session, user_question)
	local ctx = build_buffer_context(session.ctx)
	return table.concat({
		"You are an expert coding assistant.",
		"Return ONLY code as a single string suitable to insert at the cursor or replace the selection.",
		"Do not include explanations.",
		"Do not include markdown fences unless explicitly asked.",
		"",
		"<CONTEXT>",
		ctx,
		"</CONTEXT>",
		"",
		"<REQUEST>",
		user_question,
		"</REQUEST>",
	}, "\n")
end

local function extract_field(data, key)
	if type(data) ~= "table" then return nil end
	if data.info and data.info.structured and type(data.info.structured[key]) == "string" then
		return data.info.structured[key]
	end
	if type(data.parts) == "table" then
		for _, p in ipairs(data.parts) do
			if p.type == "text" and type(p.text) == "string" then
				return p.text
			end
		end
	end
	return nil
end

-- ===================== SEND REQUESTS =====================
local function send_to_model(session, kind, user_question, cb)
	ensure_server(function(server_ok)
		if not server_ok then
			notify("OpenCode server is not reachable. Start it with: opencode serve --port 4096", vim.log.levels.WARN)
			cb(false, nil)
			return
		end

		if not session.server_session_id then
			create_server_session(session.root, session.title, function(ok, sid)
				if not ok then
					notify("Failed to create OpenCode session", vim.log.levels.ERROR)
					cb(false, nil)
					return
				end
				session.server_session_id = sid
				session.server_seeded = false
				seed_server_session(session, function(seed_ok)
					if not seed_ok then
						notify("Failed to seed OpenCode session", vim.log.levels.WARN)
						cb(false, nil)
						return
					end
					send_to_model(session, kind, user_question, cb)
				end)
			end)
			return
		end

		seed_server_session(session, function(seed_ok)
			if not seed_ok then
				notify("Failed to seed OpenCode session", vim.log.levels.WARN)
				cb(false, nil)
				return
			end

			local schema_key = (kind == "inline") and "code" or "reply"
			local prompt = (kind == "inline")
				and build_inline_prompt(session, user_question)
				or build_hover_prompt(session, user_question)

			local endpoint = string.format("/session/%s/message?directory=%s", session.server_session_id,
				url_encode(session.root))
			local body = {
				agent = state.config.agent,
				reasoningEffort = state.config.reasoning_effort,
				model = {
					providerID = state.config.provider_id,
					modelID = state.config.model_id,
				},
				format = {
					type = "json_schema",
					schema = {
						type = "object",
						properties = {
							[schema_key] = {
								type = "string",
								description = (kind == "inline") and "Code to insert/replace" or "Short helpful reply",
							},
						},
						required = { schema_key },
						additionalProperties = false,
					},
				},
				parts = {
					{ type = "text", text = prompt },
				},
			}

			request(endpoint, body, function(ok, data, err, status)
				if not ok then
					if status == 404 then
						-- session expired on server; recreate
						debug_notify("server session 404; recreating")
						session.server_session_id = nil
						session.server_seeded = false
						send_to_model(session, kind, user_question, cb)
						return
					end
					if status == 0 then
						state.server_healthy = false
						state.last_health_check_ms = 0
					end
					notify("Request failed: " .. (err or "unknown error"), vim.log.levels.WARN)
					cb(false, nil)
					return
				end

				if data and data.info and data.info.error and data.info.error.message then
					notify("Model error: " .. data.info.error.message, vim.log.levels.WARN)
					cb(false, nil)
					return
				end

				local out = extract_field(data, schema_key)
				cb(true, out or "")
			end, { method = "POST" })
		end)
	end)
end

local function with_current_session(fn)
	local id = state.most_recent
	if not id then
		notify("No OpenCode chat sessions yet. Creating one…")
		M.new_session()
		id = state.most_recent
	end
	if not id then return end
	local s = state.sessions[id]
	if not s then return end
	fn(s)
end

local function chat_buf_keymaps(session)
	local bufnr = session.chat_bufnr
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then return end

	local function send_hover()
		local q = select(1, get_draft(bufnr))
		if trim(q) == "" then
			notify("Draft is empty", vim.log.levels.WARN)
			return
		end

		append_history(bufnr, "You", q)
		local pending_row = append_history(bufnr, "Assistant", "(thinking…)")
		set_draft(bufnr, "")

		send_to_model(session, "hover", q, function(ok, reply)
			if not ok then
				update_history_block(bufnr, pending_row, "(request failed)")
				return
			end
			reply = trim(reply)
			update_history_block(bufnr, pending_row, reply)
			hover_at_mark(session.ctx, reply)
		end)
	end

	local function send_inline()
		local q = select(1, get_draft(bufnr))
		if trim(q) == "" then
			notify("Draft is empty", vim.log.levels.WARN)
			return
		end

		local target_buf = session.ctx.bufnr
		if not (target_buf and vim.api.nvim_buf_is_valid(target_buf)) then
			notify("Original buffer is no longer valid", vim.log.levels.WARN)
			return
		end

		append_history(bufnr, "You", "[inline] " .. q)
		local pending_row = append_history(bufnr, "Assistant", "(thinking…)")
		set_draft(bufnr, "")

		-- Anchor for the inline suggestion: selection start, else cursor mark
		local pos = session.ctx.sel and get_mark_pos(target_buf, session.ctx.sel_start_mark) or
			get_mark_pos(target_buf, session.ctx.cursor_mark)
		pos = pos or { 0, 0 }

		-- show @Thinking… on the target line
		set_inline_thinking(target_buf, pos[1])

		send_to_model(session, "inline", q, function(ok, code)
			if not ok then
				clear_inline(target_buf)
				update_history_block(bufnr, pending_row, "(request failed)")
				return
			end

			-- Show suggestion as virtual lines (green)
			local extmark, lines = show_inline_suggestion(target_buf, pos[1], code)

			inline_state.active[target_buf] = {
				row = pos[1],
				start_mark = session.ctx.sel and session.ctx.sel_start_mark or session.ctx.cursor_mark,
				end_mark = session.ctx.sel and session.ctx.sel_end_mark or nil,
				extmark = extmark,
				code = code,
				lines = lines,
			}

			attach_accept_keymap(target_buf)
			update_history_block(bufnr, pending_row,
				"(inline suggestion ready — go to the green lines and press <leader>y)")
		end)
	end

	-- buffer-local maps
	vim.keymap.set("n", "<CR>", send_hover, { buffer = bufnr, silent = true, desc = "OpenCode Chat: send hover" })
	vim.keymap.set("n", "<leader>ci", send_inline, { buffer = bufnr, silent = true, desc = "OpenCode Chat: send inline" })
	vim.keymap.set("n", "q", function()
		if session.chat_winid and vim.api.nvim_win_is_valid(session.chat_winid) then
			vim.api.nvim_win_close(session.chat_winid, true)
		end
		session.chat_winid = nil
	end, { buffer = bufnr, silent = true, desc = "Close OpenCode Chat" })
end

-- ===================== SESSION MANAGEMENT =====================
local function push_most_recent(id)
	-- remove if exists
	local out = {}
	for _, x in ipairs(state.order) do
		if x ~= id then table.insert(out, x) end
	end
	table.insert(out, 1, id)
	state.order = out
	state.most_recent = id
end

local function open_session(session)
	local bufnr = ensure_chat_buf(session)
	local win = session.chat_winid
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
	else
		session.chat_winid = open_float(bufnr)
	end

	chat_buf_keymaps(session)

	push_most_recent(session.id)
end

function M.new_session()
	if not state.initialized then M.setup() end

	local ctx, err = capture_open_context()
	if not ctx then
		notify("Cannot open chat here: " .. tostring(err), vim.log.levels.WARN)
		return
	end

	local id = state.next_id
	state.next_id = state.next_id + 1

	local title = string.format("%s (Session %d)", ctx.path, id)
	local session = {
		id = id,
		title = title,
		created_at = os.time(),
		root = ctx.root,
		ctx = ctx,

		server_session_id = nil,
		server_seeded = false,

		chat_bufnr = nil,
		chat_winid = nil,
	}

	state.sessions[id] = session
	push_most_recent(id)

	-- Create server session eagerly (but UI opens regardless)
	ensure_server(function(server_ok)
		if not server_ok then
			debug_notify("server not reachable; will create server session on first send")
			return
		end
		create_server_session(session.root, session.title, function(ok, sid)
			if ok then
				session.server_session_id = sid
				session.server_seeded = false
				seed_server_session(session, function(_) end)
			end
		end)
	end)

	open_session(session)
end

function M.open_most_recent()
	if not state.initialized then M.setup() end
	local id = state.most_recent
	if not id or not state.sessions[id] then
		M.new_session()
		return
	end

	-- Refresh context on open so it captures the latest cursor/selection as requested.
	local ctx, err = capture_open_context()
	if ctx then
		state.sessions[id].ctx = ctx
		state.sessions[id].root = ctx.root
	else
		debug_notify("context refresh failed: " .. tostring(err))
	end

	open_session(state.sessions[id])
end

local function session_label(s)
	local when = os.date("%Y-%m-%d %H:%M", s.created_at)
	return string.format("%d  %s  (%s)", s.id, s.ctx.path, when)
end

function M.pick_session()
	if not state.initialized then M.setup() end

	local items = {}
	for _, id in ipairs(state.order) do
		local s = state.sessions[id]
		if s then
			table.insert(items, s)
		end
	end
	if #items == 0 then
		notify("No sessions", vim.log.levels.WARN)
		return
	end

	-- Prefer Telescope for fuzzy search (to mirror your <leader>l buffers picker).
	local ok_telescope, pickers = pcall(require, "telescope.pickers")
	if ok_telescope then
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		pickers.new({}, {
			prompt_title = "OpenCode sessions",
			finder = finders.new_table({
				results = items,
				entry_maker = function(s)
					return {
						value = s,
						display = session_label(s),
						ordinal = session_label(s),
					}
				end,
			}),
			sorter = conf.generic_sorter({}),
			attach_mappings = function(bufnr, _)
				actions.select_default:replace(function()
					actions.close(bufnr)
					local sel = action_state.get_selected_entry()
					if sel and sel.value then
						-- refresh context on open
						local ctx, err = capture_open_context()
						if ctx then
							sel.value.ctx = ctx
							sel.value.root = ctx.root
						else
							debug_notify("context refresh failed: " .. tostring(err))
						end
						open_session(sel.value)
					end
				end)
				return true
			end,
		}):find()
		return
	end

	-- Fallback
	vim.ui.select(items, {
		prompt = "OpenCode sessions",
		format_item = function(s) return session_label(s) end,
	}, function(choice)
		if not choice then return end
		local ctx, err = capture_open_context()
		if ctx then
			choice.ctx = ctx
			choice.root = ctx.root
		else
			debug_notify("context refresh failed: " .. tostring(err))
		end
		open_session(choice)
	end)
end

-- ===================== SETUP + DEFAULT KEYMAPS =====================
function M.setup(opts)
	if state.initialized and not opts then return end
	state.config = tbl_deep_extend(vim.deepcopy(M.config), opts or {})
	state.initialized = true
	set_default_hl()

	-- Keymaps requested:
	--   <leader>co : most recent
	--   <leader>cn : new
	--   <leader>cl : fuzzy list
	vim.keymap.set({ "n", "v" }, "<leader>co", function() M.open_most_recent() end,
		{ silent = true, desc = "OpenCode Chat: open most recent" })
	vim.keymap.set({ "n", "v" }, "<leader>cn", function() M.new_session() end,
		{ silent = true, desc = "OpenCode Chat: new session" })
	vim.keymap.set({ "n", "v" }, "<leader>cl", function() M.pick_session() end,
		{ silent = true, desc = "OpenCode Chat: list sessions" })

	-- (Optional) command
	pcall(vim.api.nvim_create_user_command, "OpenCodeChatNew", function() M.new_session() end, {})
	pcall(vim.api.nvim_create_user_command, "OpenCodeChat", function() M.open_most_recent() end, {})
end

if vim.g.opencode_copilot_chat_disable_auto_setup ~= 1 then
	M.setup()
end

return M
