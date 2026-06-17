local M = {}

local uv = vim.uv or vim.loop

local ns_assistant = vim.api.nvim_create_namespace("PiExplainAssistant")
local ns_diff = vim.api.nvim_create_namespace("PiExplainDiff")

M.config = {
	keymap = "<leader>K",
	task_keymap = "<leader>i",
	command = "pi",
	root_markers = { ".git", ".pi", "AGENTS.md", "CLAUDE.md" },
	border = "rounded",
	max_width = 110,
	max_height = 24,
	min_height = 8,
	min_width = 40,
	max_diff_chars = 60000,
	assistant_hl = "PiExplainAssistant",
	diff_add_hl = "PiExplainDiffAdd",
	diff_delete_hl = "PiExplainDiffDelete",
	append_system_prompt = table.concat({
		"You are being used from Neovim to explain code under the cursor.",
		"Answer very briefly: one or two short sentences at most.",
		"Do not modify files unless the user explicitly asks for a code change.",
		"When asked to change code, use your normal tools, inspect other project files if needed, and keep the chat reply to a short summary.",
		"Do not use markdown fences unless they are necessary.",
		"The first request for a buffer includes the whole file. Later requests may include only a unified diff; maintain the current file context from those updates.",
	}, "\n"),
}

local state = {
	sessions = {},
	expected_exit = {},
	initialized = false,
	hover = {
		buf = nil,
		win = nil,
		session = nil,
		request_id = nil,
		target_key = nil,
		anchor_win = nil,
		anchor_lnum = nil,
		anchor_col = nil,
		sticky = false,
		mode = "explain",
		return_win = nil,
	},
}

local send_followup_from_hover
local sync_buffer_after_agent
local clear_diff
local reject_pending_change
local accept_pending_change

local function notify(msg, level)
	vim.schedule(function()
		vim.notify(msg, level or vim.log.levels.INFO, { title = "Pi Explain" })
	end)
end

local function json_encode(value)
	if vim.json and vim.json.encode then return vim.json.encode(value) end
	return vim.fn.json_encode(value)
end

local function json_decode(value)
	if vim.json and vim.json.decode then return vim.json.decode(value) end
	return vim.fn.json_decode(value)
end

local function termcodes(keys)
	return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function buf_valid(bufnr)
	return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function win_valid(winid)
	return winid and vim.api.nvim_win_is_valid(winid)
end

local function split_lines(text)
	text = (text or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
	if text == "" then return { "" } end
	local lines = vim.split(text, "\n", { plain = true })
	if lines[#lines] == "" then table.remove(lines, #lines) end
	if #lines == 0 then return { "" } end
	return lines
end

local function trim(s)
	s = (s or ""):gsub("^%s+", "")
	return (s:gsub("%s+$", ""))
end

local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function hover_lines()
	if not buf_valid(state.hover.buf) then return {} end
	return vim.api.nvim_buf_get_lines(state.hover.buf, 0, -1, false)
end

local function hover_size(lines)
	local maxw = M.config.min_width
	for _, line in ipairs(lines) do
		maxw = math.max(maxw, vim.fn.strdisplaywidth(line))
	end

	local width_limit = math.max(10, math.min(M.config.max_width, vim.o.columns - 4))
	local height_limit = math.max(1, math.min(M.config.max_height, vim.o.lines - 4))
	local min_height = math.max(1, math.min(M.config.min_height or 1, height_limit))
	return clamp(maxw, M.config.min_width, width_limit), clamp(#lines, min_height, height_limit)
end

local function hover_float_config(width, height, anchor_win, anchor_lnum, anchor_col)
	anchor_win = anchor_win or state.hover.anchor_win
	anchor_lnum = anchor_lnum or state.hover.anchor_lnum
	anchor_col = anchor_col or state.hover.anchor_col
	if not (anchor_win and win_valid(anchor_win) and anchor_lnum and anchor_col) then
		return { width = width, height = height }
	end

	local pos = vim.fn.screenpos(anchor_win, anchor_lnum, anchor_col + 1)
	if not pos or not pos.row or not pos.col or pos.row <= 0 or pos.col <= 0 then
		return { width = width, height = height }
	end

	local border_extra = M.config.border and 2 or 0
	local total_width = width + border_extra
	local total_height = height + border_extra
	local columns = vim.o.columns
	local lines = vim.o.lines

	local below_space = lines - pos.row - 2
	local above_space = pos.row - 2
	local row
	if below_space >= total_height or below_space >= above_space then
		row = pos.row + 1
	else
		row = pos.row - total_height - 1
	end
	row = clamp(row, 0, math.max(0, lines - total_height - 1))

	local right_col = pos.col + 8
	local left_col = pos.col - total_width - 4
	local col
	if right_col + total_width < columns then
		col = right_col
	elseif left_col > 0 then
		col = left_col
	else
		col = math.floor((columns - total_width) / 2)
	end
	col = clamp(col, 0, math.max(0, columns - total_width - 1))

	local cfg = {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		style = "minimal",
		focusable = true,
	}
	if M.config.border then cfg.border = M.config.border end
	return cfg
end

local function resize_hover()
	if not win_valid(state.hover.win) then return end
	local width, height = hover_size(hover_lines())
	pcall(vim.api.nvim_win_set_config, state.hover.win, hover_float_config(width, height))
end

local function with_hover_modifiable(fn)
	if not buf_valid(state.hover.buf) then return end
	vim.bo[state.hover.buf].modifiable = true
	local ok, err = pcall(fn)
	vim.bo[state.hover.buf].modified = false
	if not ok then notify("Hover update failed: " .. tostring(err), vim.log.levels.ERROR) end
	resize_hover()
end

local function set_hover_lines(start_row, end_row, lines)
	with_hover_modifiable(function()
		vim.api.nvim_buf_set_lines(state.hover.buf, start_row, end_row, false, lines)
	end)
end

local function refresh_assistant_highlights(session)
	if state.hover.session ~= session or not buf_valid(state.hover.buf) then return end
	vim.api.nvim_buf_clear_namespace(state.hover.buf, ns_assistant, 0, -1)

	local lines = hover_lines()
	local function add_range(start_row, end_row)
		start_row = math.max(0, start_row or 0)
		end_row = math.min(end_row or start_row, #lines)
		for row = start_row, end_row - 1 do
			local line = lines[row + 1] or ""
			if line ~= "" then
				vim.api.nvim_buf_set_extmark(state.hover.buf, ns_assistant, row, 0, {
					hl_group = M.config.assistant_hl,
					end_col = #line,
				})
			end
		end
	end

	for _, range in ipairs(session.assistant_ranges or {}) do
		add_range(range[1], range[2])
	end
	if session.busy and session.active_start and session.active_end then
		add_range(session.active_start, session.active_end)
	end
end

local DRAFT_PREFIX = "You: "

local function find_draft_row()
	local lines = hover_lines()
	for i = #lines, 1, -1 do
		if lines[i]:sub(1, #DRAFT_PREFIX) == DRAFT_PREFIX then return i - 1, lines[i] end
	end
	return nil, nil
end

local function ensure_draft_row()
	local row, line = find_draft_row()
	if row then return row, line end
	local count = vim.api.nvim_buf_line_count(state.hover.buf)
	set_hover_lines(count, count, { DRAFT_PREFIX })
	return count, DRAFT_PREFIX
end

local function scroll_hover_to_draft()
	if not win_valid(state.hover.win) then return end
	local row, line = find_draft_row()
	if not row then return end
	pcall(vim.api.nvim_win_set_cursor, state.hover.win, { row + 1, #line })
	pcall(vim.api.nvim_win_call, state.hover.win, function()
		vim.cmd("normal! zb")
	end)
end

local function focus_hover(start_insert)
	if not win_valid(state.hover.win) then return false end
	vim.api.nvim_set_current_win(state.hover.win)
	ensure_draft_row()
	scroll_hover_to_draft()
	if start_insert then vim.cmd("startinsert!") end
	return true
end

local function clear_hover_state()
	state.hover.buf = nil
	state.hover.win = nil
	state.hover.session = nil
	state.hover.request_id = nil
	state.hover.target_key = nil
	state.hover.anchor_win = nil
	state.hover.anchor_lnum = nil
	state.hover.anchor_col = nil
	state.hover.sticky = false
	state.hover.mode = "explain"
	state.hover.return_win = nil
end

local function close_hover(session)
	if session and state.hover.session ~= session then return end
	if win_valid(state.hover.win) then
		pcall(vim.api.nvim_win_close, state.hover.win, true)
	end
	if buf_valid(state.hover.buf) then
		pcall(vim.api.nvim_buf_delete, state.hover.buf, { force = true })
	end
	clear_hover_state()
end

local function set_active_response(session, text)
	if state.hover.session ~= session or state.hover.request_id ~= session.active_request then return end
	if not buf_valid(state.hover.buf) or not session.active_start or not session.active_end then return end

	local lines = split_lines(text)
	set_hover_lines(session.active_start, session.active_end, lines)
	session.active_end = session.active_start + #lines
	refresh_assistant_highlights(session)
end

local function open_hover(session, request_id, target_key, opts)
	opts = opts or {}
	local anchor_win = vim.api.nvim_get_current_win()
	local anchor = vim.api.nvim_win_get_cursor(anchor_win)
	close_hover()

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].modifiable = true

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.initial_lines or { "Pi is thinking…", DRAFT_PREFIX })
	vim.bo[buf].modified = false

	local width, height = hover_size(vim.api.nvim_buf_get_lines(buf, 0, -1, false))
	local win = vim.api.nvim_open_win(buf, false, hover_float_config(width, height, anchor_win, anchor[1], anchor[2]))

	vim.wo[win].wrap = true
	vim.wo[win].linebreak = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].conceallevel = 2

	vim.keymap.set("n", "q", function() close_hover() end, { buffer = buf, silent = true, desc = "Close Pi explanation" })
	vim.keymap.set("n", "<Esc>", function() close_hover() end, { buffer = buf, silent = true, desc = "Close Pi explanation" })
	vim.keymap.set("n", "<CR>", function() send_followup_from_hover() end,
		{ buffer = buf, silent = true, desc = "Ask Pi follow-up" })
	vim.keymap.set("i", "<CR>", function()
		vim.cmd("stopinsert")
		vim.schedule(send_followup_from_hover)
	end, { buffer = buf, silent = true, desc = "Ask Pi follow-up" })

	state.hover.buf = buf
	state.hover.win = win
	state.hover.session = session
	state.hover.request_id = request_id
	state.hover.target_key = target_key
	state.hover.anchor_win = anchor_win
	state.hover.anchor_lnum = anchor[1]
	state.hover.anchor_col = anchor[2]
	state.hover.sticky = opts.sticky or false
	state.hover.mode = opts.mode or "explain"
	state.hover.return_win = opts.return_win
	session.active_start = opts.active_start
	session.active_end = opts.active_end
	session.assistant_ranges = {}
end

local function send_json(session, cmd)
	if not session.job_id then return false end
	return pcall(vim.fn.chansend, session.job_id, json_encode(cmd) .. "\n")
end

local function extract_text(message)
	if type(message) ~= "table" then return nil end
	if type(message.content) == "string" then return message.content end
	if type(message.content) ~= "table" then return nil end

	local parts = {}
	for _, part in ipairs(message.content) do
		if type(part) == "table" and part.type == "text" and type(part.text) == "string" then
			table.insert(parts, part.text)
		end
	end
	if #parts == 0 then return nil end
	return table.concat(parts, "\n")
end

local function last_assistant_text(messages)
	if type(messages) ~= "table" then return nil end
	for i = #messages, 1, -1 do
		local msg = messages[i]
		if type(msg) == "table" and msg.role == "assistant" then
			local text = extract_text(msg)
			if text and text ~= "" then return text end
		end
	end
	return nil
end

local function finish_active(session)
	if not session.busy then return end
	if session.active_text == "" then
		set_active_response(session, "(no explanation returned)")
	end
	if session.active_start and session.active_end then
		table.insert(session.assistant_ranges, { session.active_start, session.active_end })
	end
	session.busy = false
	session.active_request = nil
	session.active_text = ""
	session.active_start = nil
	session.active_end = nil
	refresh_assistant_highlights(session)
end

local function handle_rpc_event(session, event)
	if event.type == "extension_ui_request" then
		local dialogs = { select = true, confirm = true, input = true, editor = true }
		if event.id and dialogs[event.method] then
			send_json(session, { type = "extension_ui_response", id = event.id, cancelled = true })
		end
		return
	end

	if event.type == "response" and event.command == "prompt" and not event.success then
		if session.busy then
			session.active_text = "Pi request failed: " .. tostring(event.error or "unknown error")
			set_active_response(session, session.active_text)
			finish_active(session)
		else
			notify("Pi request failed: " .. tostring(event.error or "unknown error"), vim.log.levels.WARN)
		end
		return
	end

	if not session.busy then return end

	if event.type == "message_update" then
		local delta = event.assistantMessageEvent or {}
		if delta.type == "text_delta" and type(delta.delta) == "string" then
			session.active_text = session.active_text .. delta.delta
			set_active_response(session, session.active_text)
		elseif delta.type == "text_end" and session.active_text == "" and type(delta.content) == "string" then
			session.active_text = delta.content
			set_active_response(session, session.active_text)
		elseif delta.type == "error" then
			session.active_text = "Pi error: " .. tostring(delta.error or delta.message or "unknown error")
			set_active_response(session, session.active_text)
		end
		return
	end

	if event.type == "message_end" and event.message and event.message.role == "assistant" then
		local text = extract_text(event.message)
		if text and text ~= "" then
			session.active_text = text
			set_active_response(session, text)
		end
		return
	end

	if event.type == "agent_end" then
		if session.active_text == "" then
			local text = last_assistant_text(event.messages)
			if text and text ~= "" then
				session.active_text = text
				set_active_response(session, text)
			end
		end
		finish_active(session)
		if sync_buffer_after_agent then sync_buffer_after_agent(session) end
	end
end

local function handle_rpc_line(session, line)
	if line == "" then return end
	local ok, event = pcall(json_decode, line)
	if ok and type(event) == "table" then
		handle_rpc_event(session, event)
	end
end

local function stop_session(session, keep_autocmd)
	if not session then return end
	if not keep_autocmd and session.cleanup then
		pcall(vim.api.nvim_del_autocmd, session.cleanup)
	end
	session.cleanup = nil
	if not keep_autocmd and session.diff_cleanup then
		pcall(vim.api.nvim_del_autocmd, session.diff_cleanup)
	end
	session.diff_cleanup = nil

	if session.job_id then
		state.expected_exit[session.job_id] = true
		pcall(vim.fn.jobstop, session.job_id)
	end

	close_hover(session)
	state.sessions[session.bufnr] = nil
	session.job_id = nil
	session.busy = false
	session.active_request = nil
	session.active_text = ""
	session.active_start = nil
	session.active_end = nil
	session.assistant_ranges = nil
	session.file_snapshot = nil
	session.pre_request_file_text = nil
	session.pre_request_changedtick = nil
end

local function start_job(session)
	if vim.fn.executable(M.config.command) ~= 1 then
		notify("`" .. M.config.command .. "` not found in PATH", vim.log.levels.ERROR)
		return false
	end

	local args = {
		M.config.command,
		"--mode", "rpc",
		"--no-session",
		"--approve",
		"--name", "nvim explain",
		"--append-system-prompt", M.config.append_system_prompt,
	}

	session.stdout_buffer = ""
	session.stderr_lines = {}
	session.file_snapshot = nil

	local job_id = vim.fn.jobstart(args, {
		cwd = session.root,
		stdin = "pipe",
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data, _)
			if not data or #data == 0 then return end
			data[1] = session.stdout_buffer .. data[1]
			session.stdout_buffer = data[#data]
			for i = 1, #data - 1 do
				local line = data[i]
				vim.schedule(function() handle_rpc_line(session, line) end)
			end
		end,
		on_stderr = function(_, data, _)
			if not data then return end
			for _, line in ipairs(data) do
				if line and line ~= "" then table.insert(session.stderr_lines, line) end
			end
		end,
		on_exit = function(job, code, _)
			vim.schedule(function()
				local expected = state.expected_exit[job]
				state.expected_exit[job] = nil
				if session.job_id == job then session.job_id = nil end
				if expected then return end

				local err = table.concat(session.stderr_lines or {}, "\n")
				if session.busy then
					session.active_text = "Pi RPC exited with code " .. tostring(code) .. (err ~= "" and (": " .. err) or "")
					set_active_response(session, session.active_text)
					finish_active(session)
				else
					notify("Pi RPC exited with code " .. tostring(code), vim.log.levels.WARN)
				end
			end)
		end,
	})

	if job_id <= 0 then
		notify("Failed to start Pi RPC", vim.log.levels.ERROR)
		return false
	end

	session.job_id = job_id
	return true
end

local function get_buf_path(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then return "[No Name]" end
	return path
end

local function detect_root(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	local start = path ~= "" and vim.fs.dirname(path) or uv.cwd()
	if vim.fs and vim.fs.root then
		local root = vim.fs.root(start, M.config.root_markers)
		if root then return root end
	end
	return uv.cwd()
end

local function make_session(bufnr, root)
	local session = {
		bufnr = bufnr,
		root = root,
		job_id = nil,
		stdout_buffer = "",
		stderr_lines = {},
		busy = false,
		request_seq = 0,
		active_request = nil,
		active_text = "",
		active_start = nil,
		active_end = nil,
		file_snapshot = nil,
		assistant_ranges = {},
		pre_request_file_text = nil,
		pre_request_changedtick = nil,
		pending_change = nil,
		pending_maps = false,
		active_user_question = nil,
		last_start_lnum = nil,
		last_end_lnum = nil,
		cleanup = nil,
		diff_cleanup = nil,
	}

	session.cleanup = vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		buffer = bufnr,
		callback = function(ev)
			local current = state.sessions[ev.buf]
			if current then stop_session(current, true) end
		end,
	})

	session.diff_cleanup = vim.api.nvim_create_autocmd({ "InsertEnter", "TextChanged", "TextChangedI" }, {
		buffer = bufnr,
		callback = function(ev)
			if clear_diff then clear_diff(ev.buf) end
		end,
	})

	state.sessions[bufnr] = session
	return session
end

local function ensure_session(bufnr, root)
	local session = state.sessions[bufnr]
	if session and session.root ~= root then
		stop_session(session)
		session = nil
	end
	if not session then session = make_session(bufnr, root) end
	if not session.job_id and not start_job(session) then return nil end
	return session
end

local function save_buffer_if_needed(bufnr)
	if not buf_valid(bufnr) or not vim.bo[bufnr].modified then return true end
	if vim.api.nvim_buf_get_name(bufnr) == "" then return true end

	local ok, err = pcall(vim.api.nvim_buf_call, bufnr, function()
		vim.cmd("silent noautocmd keepjumps write!")
	end)
	if not ok or vim.bo[bufnr].modified then
		notify("Could not save current buffer before sending it to Pi: " .. tostring(err or "write failed"), vim.log.levels.ERROR)
		return false
	end
	return true
end

local function relpath(path, root)
	if not path or path == "[No Name]" then return path or "[No Name]" end
	if root and path:sub(1, #root) == root then
		local rel = path:sub(#root + 2)
		if rel ~= "" then return rel end
	end
	return path
end

local function selected_range(from_visual)
	if from_visual then
		local mode = vim.fn.mode()
		local start_pos, end_pos
		if mode:match("^[vV\022]") then
			start_pos = vim.fn.getpos("v")
			end_pos = vim.fn.getcurpos()
			vim.api.nvim_feedkeys(termcodes("<Esc>"), "n", false)
		else
			start_pos = vim.fn.getpos("'<")
			end_pos = vim.fn.getpos("'>")
		end
		local sr, er = start_pos[2], end_pos[2]
		if sr > er then sr, er = er, sr end
		return sr, er
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	return line, line
end

local function numbered_lines(lines, first_lnum)
	first_lnum = first_lnum or 1
	local last_lnum = first_lnum + #lines - 1
	local width = #tostring(last_lnum)
	local out = {}
	for i, line in ipairs(lines) do
		table.insert(out, string.format("%" .. width .. "d: %s", first_lnum + i - 1, line))
	end
	return table.concat(out, "\n")
end

local function write_temp(path, text)
	return vim.fn.writefile(vim.split(text, "\n", { plain = true }), path, "b") == 0
end

local function unified_diff(old_text, new_text, display_path)
	if old_text == new_text then return "" end
	if vim.fn.executable("diff") ~= 1 then return nil end

	local base = string.format("/tmp/pi-explain-%d-%d-%d", vim.fn.getpid(), math.random(1000000), os.time())
	local old_file = base .. ".previous"
	local new_file = base .. ".current"
	if not write_temp(old_file, old_text) or not write_temp(new_file, new_text) then
		pcall(vim.fn.delete, old_file)
		pcall(vim.fn.delete, new_file)
		return nil
	end

	local out = vim.fn.system({ "diff", "-u", old_file, new_file })
	pcall(vim.fn.delete, old_file)
	pcall(vim.fn.delete, new_file)

	if vim.v.shell_error ~= 0 and vim.v.shell_error ~= 1 then return nil end
	out = out:gsub(vim.pesc(old_file), display_path .. " (previous)")
	out = out:gsub(vim.pesc(new_file), display_path .. " (current)")
	return out
end

clear_diff = function(bufnr)
	if buf_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, ns_diff, 0, -1)
	end
end

local function read_file_text(path)
	if not path or path == "" or path == "[No Name]" then return nil end
	if vim.fn.filereadable(path) ~= 1 then return nil end
	local ok, lines = pcall(vim.fn.readfile, path, "b")
	if not ok then return nil end
	return table.concat(lines, "\n")
end

local function apply_diff_preview(bufnr, old_text, new_text, display_path)
	clear_diff(bufnr)
	old_text = old_text or ""
	new_text = new_text or ""
	if old_text == new_text then return {} end
	local changed_lnums = {}

	local ok, hunks = pcall(vim.diff, old_text, new_text, {
		result_type = "indices",
		algorithm = "histogram",
	})
	if not ok or type(hunks) ~= "table" or #hunks == 0 then
		hunks = nil
	end
	if not hunks then return {} end

	local old_lines = vim.split(old_text, "\n", { plain = true })
	local new_lines = vim.split(new_text, "\n", { plain = true })
	local line_count = math.max(1, vim.api.nvim_buf_line_count(bufnr))

	local function count_lines(lines, start_lnum, count)
		local counts = {}
		for i = 0, count - 1 do
			local text = lines[start_lnum + i] or ""
			counts[text] = (counts[text] or 0) + 1
		end
		return counts
	end

	local function common_counts(old_start, old_count, new_start, new_count)
		local old_counts = count_lines(old_lines, old_start, old_count)
		local new_counts = count_lines(new_lines, new_start, new_count)
		local common = {}
		for text, old_count_for_text in pairs(old_counts) do
			local new_count_for_text = new_counts[text]
			if new_count_for_text then
				common[text] = math.min(old_count_for_text, new_count_for_text)
			end
		end
		return common
	end

	local function take_common(common, text)
		if (common[text] or 0) <= 0 then return false end
		common[text] = common[text] - 1
		return true
	end

	for _, hunk in ipairs(hunks) do
		local old_start, old_count, new_start, new_count = hunk[1], hunk[2], hunk[3], hunk[4]

		while old_count > 0 and new_count > 0 and old_lines[old_start] == new_lines[new_start] do
			old_start = old_start + 1
			new_start = new_start + 1
			old_count = old_count - 1
			new_count = new_count - 1
		end
		while old_count > 0 and new_count > 0 and old_lines[old_start + old_count - 1] == new_lines[new_start + new_count - 1] do
			old_count = old_count - 1
			new_count = new_count - 1
		end

		if old_count > 0 or new_count > 0 then
			local common_for_deletes = common_counts(old_start, old_count, new_start, new_count)
			local common_for_adds = vim.deepcopy(common_for_deletes)
			local deleted_virt_lines = {}

			for i = 0, old_count - 1 do
				local text = old_lines[old_start + i] or ""
				if not take_common(common_for_deletes, text) then
					table.insert(deleted_virt_lines, { { "- " .. text, M.config.diff_delete_hl } })
				end
			end

			if #deleted_virt_lines > 0 then
				local row = math.max(0, math.min((new_start or 1) - 1, line_count - 1))
				changed_lnums[row + 1] = true
				vim.api.nvim_buf_set_extmark(bufnr, ns_diff, row, 0, {
					virt_lines = deleted_virt_lines,
					virt_lines_above = true,
				})
			end

			for i = 0, new_count - 1 do
				local text = new_lines[new_start + i] or ""
				if not take_common(common_for_adds, text) then
					local row = math.max(0, math.min(new_start + i - 1, line_count - 1))
					changed_lnums[row + 1] = true
					vim.api.nvim_buf_set_extmark(bufnr, ns_diff, row, 0, {
						line_hl_group = M.config.diff_add_hl,
					})
				end
			end
		end
	end
	return changed_lnums
end

local function cursor_in_pending_change(session)
	if not session or not session.pending_change then return false end
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	return session.pending_change.changed_lnums and session.pending_change.changed_lnums[lnum]
end

local function clear_pending_change(session)
	if not session then return end
	clear_diff(session.bufnr)
	session.pending_change = nil
end

local function install_pending_maps(session)
	if session.pending_maps or not buf_valid(session.bufnr) then return end
	session.pending_maps = true
	vim.keymap.set("n", "<leader>pa", function()
		if cursor_in_pending_change(session) then
			accept_pending_change(session)
		else
			notify("Move cursor onto a Pi-changed line to accept", vim.log.levels.WARN)
		end
	end, { buffer = session.bufnr, silent = true, desc = "Accept Pi change" })
	vim.keymap.set("n", "<leader>pr", function()
		if cursor_in_pending_change(session) then
			reject_pending_change(session)
		else
			notify("Move cursor onto a Pi-changed line to reject", vim.log.levels.WARN)
		end
	end, { buffer = session.bufnr, silent = true, desc = "Reject Pi change" })
end

accept_pending_change = function(session)
	if not session or not session.pending_change then return end
	clear_pending_change(session)
	notify("Pi change accepted")
end

reject_pending_change = function(session)
	local change = session and session.pending_change
	if not change then return end
	local path = vim.api.nvim_buf_get_name(session.bufnr)
	local before_lines = vim.split(change.before or "", "\n", { plain = true })
	vim.api.nvim_buf_set_lines(session.bufnr, 0, -1, false, before_lines)
	if path ~= "" then
		vim.api.nvim_buf_call(session.bufnr, function()
			pcall(vim.cmd, "silent keepjumps write")
		end)
	end
	clear_pending_change(session)
	session.file_snapshot = change.before
	session.last_start_lnum = change.start_lnum
	session.last_end_lnum = change.end_lnum

	local target_key = table.concat({ tostring(session.bufnr), tostring(change.start_lnum), tostring(change.end_lnum), tostring(vim.api.nvim_buf_get_changedtick(session.bufnr)) }, ":")
	open_hover(session, nil, target_key, {
		initial_lines = { "Rejected. Tell Pi what to do differently:", DRAFT_PREFIX },
		mode = "task",
		sticky = true,
		return_win = vim.api.nvim_get_current_win(),
	})
	focus_hover(true)
end

sync_buffer_after_agent = function(session)
	if not session or not buf_valid(session.bufnr) then return end
	local before = session.pre_request_file_text or session.file_snapshot
	if not before then return end

	local path = vim.api.nvim_buf_get_name(session.bufnr)
	local after = read_file_text(path)
	session.pre_request_file_text = nil
	session.pre_request_changedtick = nil
	if not after or after == before then return end

	local current = table.concat(vim.api.nvim_buf_get_lines(session.bufnr, 0, -1, false), "\n")
	if current ~= before and current ~= after then
		notify("Pi changed the file on disk, but the buffer also changed; not auto-reloading", vim.log.levels.WARN)
		return
	end

	if current ~= after then
		local source_win = vim.api.nvim_get_current_win()
		vim.api.nvim_buf_call(session.bufnr, function()
			pcall(vim.cmd, "silent keepjumps edit!")
		end)
		if win_valid(source_win) then pcall(vim.api.nvim_set_current_win, source_win) end
	end

	session.file_snapshot = after
	local changed_lnums = apply_diff_preview(session.bufnr, before, after, path)
	if changed_lnums and next(changed_lnums) then
		session.pending_change = {
			before = before,
			after = after,
			changed_lnums = changed_lnums,
			start_lnum = session.last_start_lnum,
			end_lnum = session.last_end_lnum,
			question = session.active_user_question,
		}
		install_pending_maps(session)
		notify("Pi change ready: <leader>pa accepts, <leader>pr rejects")
	end
	session.active_user_question = nil
end

local function build_ctx(session, start_lnum, end_lnum)
	if not buf_valid(session.bufnr) then return nil end
	local lines = vim.api.nvim_buf_get_lines(session.bufnr, 0, -1, false)
	if #lines == 0 then lines = { "" } end
	start_lnum = math.max(1, math.min(start_lnum or 1, #lines))
	end_lnum = math.max(1, math.min(end_lnum or start_lnum, #lines))
	if end_lnum < start_lnum then start_lnum, end_lnum = end_lnum, start_lnum end

	local path = get_buf_path(session.bufnr)
	local display_path = relpath(path, session.root)
	local target_lines = vim.api.nvim_buf_get_lines(session.bufnr, start_lnum - 1, end_lnum, false)
	return {
		root = session.root,
		path = path,
		display_path = display_path,
		filetype = vim.bo[session.bufnr].filetype,
		start_lnum = start_lnum,
		end_lnum = end_lnum,
		target_text = numbered_lines(target_lines, start_lnum),
		file_text = numbered_lines(lines, 1),
		raw_file_text = table.concat(lines, "\n"),
	}
end

local function context_update(session, ctx)
	if not ctx then return "Current file buffer is no longer available." end
	if not session.file_snapshot then
		return table.concat({
			"This is the first request for this buffer in this Pi session. Remember this current full file for later requests.",
			"<WHOLE_FILE_WITH_LINE_NUMBERS>",
			ctx.file_text,
			"</WHOLE_FILE_WITH_LINE_NUMBERS>",
		}, "\n")
	end

	if session.file_snapshot == ctx.raw_file_text then
		return "The full file was sent earlier in this same Pi session. File unchanged since the previous request."
	end

	local diff = unified_diff(session.file_snapshot, ctx.raw_file_text, ctx.display_path)
	if diff and diff ~= "" and #diff <= M.config.max_diff_chars then
		return table.concat({
			"The full file was sent earlier in this same Pi session. Apply this unified diff to update your current file context before answering.",
			"<FILE_UPDATE_UNIFIED_DIFF>",
			diff,
			"</FILE_UPDATE_UNIFIED_DIFF>",
		}, "\n")
	end

	return table.concat({
		"The previous file context is stale and the diff was unavailable or too large, so here is a refreshed full file.",
		"<WHOLE_FILE_WITH_LINE_NUMBERS>",
		ctx.file_text,
		"</WHOLE_FILE_WITH_LINE_NUMBERS>",
	}, "\n")
end

local function build_explain_prompt(session, ctx)
	local many = ctx.start_lnum ~= ctx.end_lnum
	local instruction = many and "Explain these multiple lines very shortly." or "Explain this line very shortly."
	local target = many and string.format("lines %d-%d", ctx.start_lnum, ctx.end_lnum) or string.format("line %d", ctx.start_lnum)

	return table.concat({
		instruction,
		"Answer in one or two short sentences. Trust the target text below if it conflicts with older context.",
		"Do not edit files and do not mention that you cannot edit files.",
		"",
		"Project root: " .. ctx.root,
		"File: " .. ctx.path,
		"Filetype: " .. ((ctx.filetype ~= "" and ctx.filetype) or "plain"),
		"Target: " .. target,
		"",
		"<TARGET_WITH_LINE_NUMBERS>",
		ctx.target_text,
		"</TARGET_WITH_LINE_NUMBERS>",
		"",
		context_update(session, ctx),
	}, "\n")
end

local function build_task_prompt(session, question, ctx)
	local parts = {
		"User task: " .. question,
		"",
		"You are in code-change mode from Neovim.",
		"Use your tools to inspect and edit files when needed.",
		"Prefer editing the current file/selection unless the user asks otherwise.",
		"Keep your final chat reply to one short summary sentence.",
	}

	if ctx then
		local target = (ctx.start_lnum ~= ctx.end_lnum)
			and string.format("lines %d-%d", ctx.start_lnum, ctx.end_lnum)
			or string.format("line %d", ctx.start_lnum)
		vim.list_extend(parts, {
			"",
			"Project root: " .. ctx.root,
			"File: " .. ctx.path,
			"Filetype: " .. ((ctx.filetype ~= "" and ctx.filetype) or "plain"),
			"Target: " .. target,
			"",
			"<TARGET_WITH_LINE_NUMBERS>",
			ctx.target_text,
			"</TARGET_WITH_LINE_NUMBERS>",
			"",
			context_update(session, ctx),
		})
	end

	return table.concat(parts, "\n")
end

local function build_followup_prompt(session, question, ctx)
	local parts = {
		"Answer this follow-up question about the currently displayed code explanation.",
		"Keep the answer very short unless the question explicitly asks for more detail.",
		"Do not edit files unless this question explicitly asks for a code change. If it does, use your normal tools and inspect other project files if needed.",
		"",
		"Question: " .. question,
	}

	if ctx then
		local target = (ctx.start_lnum ~= ctx.end_lnum)
			and string.format("lines %d-%d", ctx.start_lnum, ctx.end_lnum)
			or string.format("line %d", ctx.start_lnum)
		vim.list_extend(parts, {
			"",
			"Project root: " .. ctx.root,
			"File: " .. ctx.path,
			"Filetype: " .. ((ctx.filetype ~= "" and ctx.filetype) or "plain"),
			"Current target: " .. target,
			"",
			"<CURRENT_TARGET_WITH_LINE_NUMBERS>",
			ctx.target_text,
			"</CURRENT_TARGET_WITH_LINE_NUMBERS>",
			"",
			context_update(session, ctx),
		})
	end

	return table.concat(parts, "\n")
end

local function begin_request(session, request_id, response_start, response_end)
	session.active_request = request_id
	session.active_text = ""
	session.active_start = response_start
	session.active_end = response_end
	session.busy = true
	refresh_assistant_highlights(session)
end

local function send_prompt(session, prompt, ctx)
	if ctx then
		clear_diff(session.bufnr)
		if not save_buffer_if_needed(session.bufnr) then
			session.active_text = "Could not save current buffer before sending it to Pi."
			set_active_response(session, session.active_text)
			finish_active(session)
			return false
		end
		session.pre_request_file_text = ctx.raw_file_text
		session.pre_request_changedtick = vim.api.nvim_buf_get_changedtick(session.bufnr)
	end

	local ok = send_json(session, { id = session.active_request, type = "prompt", message = prompt })
	if ok then
		if ctx then session.file_snapshot = ctx.raw_file_text end
		return true
	end

	session.active_text = "Failed to send prompt to Pi RPC"
	set_active_response(session, session.active_text)
	finish_active(session)
	return false
end

send_followup_from_hover = function()
	local session = state.hover.session
	if not session or not buf_valid(state.hover.buf) then return end
	if session.busy then
		notify("Pi is still answering", vim.log.levels.WARN)
		return
	end

	local row, line = ensure_draft_row()
	local question = trim((line or ""):sub(#DRAFT_PREFIX + 1))
	if question == "" then
		focus_hover(true)
		return
	end

	local mode = state.hover.mode or "explain"
	local return_win = state.hover.return_win
	session.request_seq = session.request_seq + 1
	local request_id = "pi-" .. mode .. "-" .. tostring(session.bufnr) .. "-" .. tostring(session.request_seq)

	set_hover_lines(row, row + 1, { "You: " .. question, "Pi is thinking…", DRAFT_PREFIX })
	begin_request(session, request_id, row + 1, row + 2)
	state.hover.request_id = request_id

	if not save_buffer_if_needed(session.bufnr) then return end
	local ctx = build_ctx(session, session.last_start_lnum, session.last_end_lnum)
	local prompt = (mode == "task") and build_task_prompt(session, question, ctx) or build_followup_prompt(session, question, ctx)
	session.active_user_question = question
	send_prompt(session, prompt, ctx)
	if mode == "task" and return_win and win_valid(return_win) then
		vim.api.nvim_set_current_win(return_win)
	end
end

local function cursor_is_inside_target(session)
	local start_lnum = session.last_start_lnum
	local end_lnum = session.last_end_lnum
	if not start_lnum or not end_lnum then return false end
	local cursor_lnum = vim.api.nvim_win_get_cursor(0)[1]
	return cursor_lnum >= start_lnum and cursor_lnum <= end_lnum
end

local function source_context_from_cursor(source_buf, from_visual)
	local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
	if #lines == 0 then lines = { "" } end
	local start_lnum, end_lnum = selected_range(from_visual)
	start_lnum = math.max(1, math.min(start_lnum, #lines))
	end_lnum = math.max(1, math.min(end_lnum, #lines))
	if end_lnum < start_lnum then start_lnum, end_lnum = end_lnum, start_lnum end
	return start_lnum, end_lnum
end

function M.explain(from_visual)
	local source_buf = vim.api.nvim_get_current_buf()
	if vim.bo[source_buf].buftype ~= "" then
		notify("Pi Explain works on normal file buffers only", vim.log.levels.WARN)
		return
	end

	local root = detect_root(source_buf)
	local session = ensure_session(source_buf, root)
	if not session then return end

	if not from_visual and state.hover.session == session and win_valid(state.hover.win) and cursor_is_inside_target(session) then
		focus_hover(true)
		return
	end

	local start_lnum, end_lnum = source_context_from_cursor(source_buf, from_visual)

	local target_key = table.concat({
		tostring(source_buf),
		tostring(start_lnum),
		tostring(end_lnum),
		tostring(vim.api.nvim_buf_get_changedtick(source_buf)),
	}, ":")

	if state.hover.session == session and state.hover.target_key == target_key and win_valid(state.hover.win) then
		focus_hover(true)
		return
	end

	if session.busy then
		if state.hover.session == session and win_valid(state.hover.win) then focus_hover(true) end
		notify("Pi is still answering for this buffer", vim.log.levels.WARN)
		return
	end

	if not save_buffer_if_needed(source_buf) then return end
	local ctx = build_ctx(session, start_lnum, end_lnum)
	if not ctx then return end
	session.last_start_lnum = start_lnum
	session.last_end_lnum = end_lnum
	session.request_seq = session.request_seq + 1
	local request_id = "pi-explain-" .. tostring(source_buf) .. "-" .. tostring(session.request_seq)

	open_hover(session, request_id, target_key)
	begin_request(session, request_id, 0, 1)
	send_prompt(session, build_explain_prompt(session, ctx), ctx)
end

function M.task(from_visual)
	local source_buf = vim.api.nvim_get_current_buf()
	if vim.bo[source_buf].buftype ~= "" then
		notify("Pi task works on normal file buffers only", vim.log.levels.WARN)
		return
	end

	local root = detect_root(source_buf)
	local session = ensure_session(source_buf, root)
	if not session then return end
	if session.busy then
		notify("Pi is still answering for this buffer", vim.log.levels.WARN)
		return
	end

	local start_lnum, end_lnum = source_context_from_cursor(source_buf, from_visual)
	session.last_start_lnum = start_lnum
	session.last_end_lnum = end_lnum
	local target_key = table.concat({
		tostring(source_buf),
		tostring(start_lnum),
		tostring(end_lnum),
		"task",
	}, ":")

	if not save_buffer_if_needed(source_buf) then return end
	open_hover(session, nil, target_key, {
		initial_lines = { DRAFT_PREFIX },
		mode = "task",
		sticky = true,
		return_win = vim.api.nvim_get_current_win(),
	})
	focus_hover(true)
end

local function stop_all_sessions()
	local sessions = {}
	for _, session in pairs(state.sessions) do table.insert(sessions, session) end
	for _, session in ipairs(sessions) do stop_session(session) end
	close_hover()
end

local function close_hover_if_cursor_left_target()
	local session = state.hover.session
	if not session or not win_valid(state.hover.win) then return end
	if state.hover.sticky then return end

	local current_buf = vim.api.nvim_get_current_buf()
	if current_buf == state.hover.buf then return end
	if current_buf ~= session.bufnr then
		close_hover(session)
		return
	end

	if not cursor_is_inside_target(session) then
		close_hover(session)
	end
end

function M.close_floats()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(win)
		if cfg and cfg.relative and cfg.relative ~= "" then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	if state.hover.win and not win_valid(state.hover.win) then
		if buf_valid(state.hover.buf) then
			pcall(vim.api.nvim_buf_delete, state.hover.buf, { force = true })
		end
		clear_hover_state()
	end
end

function M.setup(opts)
	if opts then M.config = vim.tbl_deep_extend("force", M.config, opts) end
	pcall(vim.api.nvim_set_hl, 0, M.config.assistant_hl, { link = "DiagnosticInfo", default = true })
	pcall(vim.api.nvim_set_hl, 0, M.config.diff_add_hl, { link = "DiffAdd", default = true })
	pcall(vim.api.nvim_set_hl, 0, M.config.diff_delete_hl, { link = "DiffDelete", default = true })
	if state.initialized then return end
	state.initialized = true

	vim.keymap.set("n", M.config.keymap, function() M.explain(false) end,
		{ silent = true, desc = "Pi: explain current line" })
	vim.keymap.set("x", M.config.keymap, function() M.explain(true) end,
		{ silent = true, desc = "Pi: explain selected lines" })
	vim.keymap.set("n", M.config.task_keymap, function() M.task(false) end,
		{ silent = true, desc = "Pi: task for current line" })
	vim.keymap.set("x", M.config.task_keymap, function() M.task(true) end,
		{ silent = true, desc = "Pi: task for selected lines" })
	vim.keymap.set("n", "<leader>pq", function() M.close_floats() end,
		{ silent = true, desc = "Pi: close floating boxes" })

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
		callback = close_hover_if_cursor_left_target,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = stop_all_sessions,
	})
end

return M
