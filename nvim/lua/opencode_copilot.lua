local M = {}

local uv = vim.uv or vim.loop
local ns = vim.api.nvim_create_namespace("OpenCodeCopilotGhost")

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
	reuse_session = true,
	session_max_requests = 8,
	dedupe_same_signature = false,
	poll_delay_ms = 5000,
	request_timeout_ms = 60000,
	health_cache_ms = 10000,
	context_lines_before = 80,
	context_lines_after = 60,
	prefix_max_chars = 3500,
	suffix_max_chars = 1800,
	max_completion_chars = nil,
	history_max_items = 30,
	history_in_prompt = 6,
	min_prefix_chars = 0,
	last_buffer_tail_lines = 120,
	last_buffer_max_chars = 2600,
	ghost_hl_group = "Comment",
	normalize_tabs = true,
	tab_width = nil,
	manual_trigger_keys = { "<D-i>", "<M-i>" },
	map_tab = true,
	debug = false,
}

local state = {
	config = nil,
	session_id = nil,
	session_root = nil,
	suggestion = nil,
	poll_timer = nil,
	pending_request = nil,
	request_seq = 0,
	last_signature = nil,
	accepted_history = {},
	last_buffer_context = nil,
	last_health_check_ms = 0,
	server_healthy = false,
	health_check_inflight = false,
	starting_server = false,
	seeded_session = false,
	session_request_count = 0,
	initialized = false,
	context_version = 0,
}

local function now_ms()
	return math.floor(uv.hrtime() / 1000000)
end

local function notify(msg, level)
	vim.schedule(function()
		vim.notify(msg, level or vim.log.levels.INFO, { title = "OpenCode Copilot" })
	end)
end

local function debug_notify(msg)
	if state.config and state.config.debug then
		notify("[debug] " .. msg, vim.log.levels.INFO)
	end
end

local function json_encode(v)
	if vim.json and vim.json.encode then
		return vim.json.encode(v)
	end
	return vim.fn.json_encode(v)
end

local function json_decode(v)
	if vim.json and vim.json.decode then
		return vim.json.decode(v)
	end
	return vim.fn.json_decode(v)
end

local function termcodes(keys)
	return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function is_insert_mode()
	local m = vim.api.nvim_get_mode().mode
	if m:sub(1, 1) == "i" or m:sub(1, 1) == "R" then
		return true
	end
	if m:match("^ni") then
		return true
	end
	return false
end

local function tbl_deep_extend(dst, src)
	if type(src) ~= "table" then
		return dst
	end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then
			tbl_deep_extend(dst[k], v)
		else
			dst[k] = v
		end
	end
	return dst
end

local function url_encode(value)
	if vim.uri_encode then
		return vim.uri_encode(value)
	end
	return (value:gsub("([^%w%-_%.~])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function truncate_left(text, max_chars)
	if type(max_chars) ~= "number" or max_chars <= 0 then
		return text
	end
	if #text <= max_chars then
		return text
	end
	return text:sub(#text - max_chars + 1)
end

local function truncate_right(text, max_chars)
	if type(max_chars) ~= "number" or max_chars <= 0 then
		return text
	end
	if #text <= max_chars then
		return text
	end
	return text:sub(1, max_chars)
end

local function split_lines(text)
	if text == "" then
		return { "" }
	end
	return vim.split(text, "\n", { plain = true })
end

local function expand_tabs_for_line(line, tab_width, start_col)
	if not line:find("\t", 1, true) then
		return line
	end

	local out = {}
	local col = start_col or 0
	for i = 1, #line do
		local ch = line:sub(i, i)
		if ch == "\t" then
			local spaces = tab_width - (col % tab_width)
			if spaces <= 0 then
				spaces = tab_width
			end
			table.insert(out, string.rep(" ", spaces))
			col = col + spaces
		else
			table.insert(out, ch)
			col = col + vim.fn.strdisplaywidth(ch)
		end
	end
	return table.concat(out)
end

local function get_buf_path(bufnr)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return nil
	end
	return path
end

local function detect_root(bufnr)
	local path = get_buf_path(bufnr)
	local start = path and vim.fs.dirname(path) or uv.cwd()
	if vim.fs and vim.fs.root then
		local root = vim.fs.root(start, { ".git", "opencode.json", ".opencode" })
		if root then
			return root
		end
	end
	return uv.cwd()
end

local function clear_timer()
	if state.poll_timer then
		pcall(function()
			state.poll_timer:stop()
		end)
	end
end

local function clear_suggestion()
	local bufnr = state.suggestion and state.suggestion.bufnr or vim.api.nvim_get_current_buf()
	state.suggestion = nil
	if vim.api.nvim_buf_is_valid(bufnr) then
		pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, 0, -1)
	end
end

local function abort_pending_request()
	if state.pending_request and state.pending_request.kill then
		pcall(function()
			state.pending_request:kill(15)
		end)
	end
	state.pending_request = nil
end

local function trim_completion_overlap(completion, suffix)
	if completion == "" or suffix == "" then
		return completion
	end
	local max_overlap = math.min(#completion, #suffix)
	for size = max_overlap, 1, -1 do
		if completion:sub(#completion - size + 1) == suffix:sub(1, size) then
			return completion:sub(1, #completion - size)
		end
	end
	return completion
end

local function trim_prefix_overlap(completion, prefix)
	if completion == "" or prefix == "" then
		return completion
	end

	local tail = prefix
	if #tail > 400 then
		tail = tail:sub(#tail - 399)
	end

	local max_overlap = math.min(#completion, #tail)
	for size = max_overlap, 1, -1 do
		if completion:sub(1, size) == tail:sub(#tail - size + 1) then
			return completion:sub(size + 1)
		end
	end

	return completion
end

local function effective_tab_width(bufnr)
	local configured = state.config.tab_width
	if type(configured) == "number" and configured > 0 then
		return configured
	end
	local sw = vim.bo[bufnr].shiftwidth
	if sw and sw > 0 then
		return sw
	end
	local ts = vim.bo[bufnr].tabstop
	if ts and ts > 0 then
		return ts
	end
	return 4
end

local function normalize_tabs(text, bufnr)
	if not state.config.normalize_tabs then
		return text
	end
	local width = effective_tab_width(bufnr)
	local lines = split_lines(text)
	for i, line in ipairs(lines) do
		lines[i] = expand_tabs_for_line(line, width, 0)
	end
	return table.concat(lines, "\n")
end

local function normalize_tabs_with_context(text, ctx)
	if not state.config.normalize_tabs then
		return text
	end
	local width = effective_tab_width(ctx.bufnr)
	local lines = split_lines(text)
	for i, line in ipairs(lines) do
		local start_col = (i == 1) and (ctx.prefix_display_width or 0) or 0
		lines[i] = expand_tabs_for_line(line, width, start_col)
	end
	return table.concat(lines, "\n")
end

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

	local proc = vim.system(curl, { text = true }, function(obj)
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
			vim.schedule(function()
				on_done(true, {}, nil, 200)
			end)
			return
		end

		local ok, parsed = pcall(json_decode, stdout)
		if not ok then
			vim.schedule(function()
				on_done(false, nil, "Failed to parse server JSON", 0)
			end)
			return
		end

		vim.schedule(function()
			on_done(true, parsed, nil, 200)
		end)
	end)

	if opts.track_pending then
		state.pending_request = proc
	end

	return proc
end

local function ensure_server(cb)
	local cfg = state.config
	local now = now_ms()
	if state.server_healthy then
		if (now - state.last_health_check_ms) < cfg.health_cache_ms then
			cb(true)
			return
		end

		cb(true)
		if not state.health_check_inflight then
			state.health_check_inflight = true
			request("/global/health", nil, function(ok)
				state.health_check_inflight = false
				state.last_health_check_ms = now_ms()
				state.server_healthy = ok
				if ok then
					debug_notify("OpenCode background health check: OK")
				else
					debug_notify("OpenCode background health check: FAILED")
				end
			end)
		end
		return
	end

	state.health_check_inflight = true
	request("/global/health", nil, function(ok)
		state.health_check_inflight = false
		state.last_health_check_ms = now_ms()
		state.server_healthy = ok
		if ok then
			debug_notify("OpenCode server health check: OK")
			cb(true)
			return
		end

		if not cfg.auto_start_server or state.starting_server then
			debug_notify("OpenCode server health check: FAILED")
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

local function extract_completion(response)
	if type(response) ~= "table" then
		return nil
	end

	if response.info and response.info.structured and type(response.info.structured.completion) == "string" then
		return response.info.structured.completion
	end

	if type(response.parts) == "table" then
		for _, part in ipairs(response.parts) do
			if part.type == "text" and type(part.text) == "string" then
				return part.text
			end
		end
	end

	return nil
end

local function suggestion_is_still_valid()
	local s = state.suggestion
	if not s then
		return false
	end
	if not is_insert_mode() then
		return false
	end
	if vim.api.nvim_get_current_buf() ~= s.bufnr then
		return false
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	if (cursor[1] - 1) ~= s.row or cursor[2] ~= s.col then
		return false
	end
	return vim.api.nvim_buf_get_changedtick(s.bufnr) == s.changedtick
end

local function render_suggestion()
	if not suggestion_is_still_valid() then
		clear_suggestion()
		return
	end

	local s = state.suggestion
	vim.api.nvim_buf_clear_namespace(s.bufnr, ns, 0, -1)

	local lines = split_lines(s.text)
	local first = lines[1] or ""
	local extmark_opts = {
		virt_text = { { first, state.config.ghost_hl_group } },
		virt_text_pos = "inline",
		hl_mode = "combine",
	}

	if #lines > 1 then
		local virt_lines = {}
		for i = 2, #lines do
			table.insert(virt_lines, { { lines[i], state.config.ghost_hl_group } })
		end
		extmark_opts.virt_lines = virt_lines
		extmark_opts.virt_lines_above = false
	end

	local ok = pcall(vim.api.nvim_buf_set_extmark, s.bufnr, ns, s.row, s.col, extmark_opts)

	if not ok then
		pcall(vim.api.nvim_buf_set_extmark, s.bufnr, ns, s.row, s.col, {
			virt_text = { { first, state.config.ghost_hl_group } },
			virt_text_pos = "overlay",
			hl_mode = "combine",
		})
	end
end

local function set_suggestion(ctx, text)
	text = text or ""
	if text == "" then
		clear_suggestion()
		return
	end

	state.suggestion = {
		bufnr = ctx.bufnr,
		row = ctx.row,
		col = ctx.col,
		changedtick = ctx.changedtick,
		text = text,
	}
	render_suggestion()
end

local function build_context(require_eol)
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.bo[bufnr].buftype ~= "" then
		return nil, "unsupported buftype: " .. vim.bo[bufnr].buftype
	end
	if not vim.bo[bufnr].modifiable or vim.bo[bufnr].readonly then
		return nil, "buffer is not modifiable"
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]
	local line = vim.api.nvim_get_current_line()
	local line_prefix = line:sub(1, col)
	local line_suffix = line:sub(col + 1)
	local prefix_display_width = vim.fn.strdisplaywidth(line_prefix)

	if require_eol and line_suffix ~= "" then
		return nil, "cursor is not at end of line"
	end

	if #line_prefix < state.config.min_prefix_chars then
		return nil, "not enough prefix characters"
	end

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local before_start = math.max(0, row - state.config.context_lines_before)
	local before_lines = vim.api.nvim_buf_get_lines(bufnr, before_start, row + 1, false)
	before_lines[#before_lines] = line_prefix

	local after_end = math.min(line_count, row + state.config.context_lines_after + 1)
	local after_lines = vim.api.nvim_buf_get_lines(bufnr, row, after_end, false)
	after_lines[1] = line_suffix

	local path = get_buf_path(bufnr) or "[No Name]"

	return {
		bufnr = bufnr,
		row = row,
		col = col,
		prefix_display_width = prefix_display_width,
		changedtick = vim.api.nvim_buf_get_changedtick(bufnr),
		filetype = vim.bo[bufnr].filetype,
		path = path,
		root = detect_root(bufnr),
		prefix = truncate_left(table.concat(before_lines, "\n"), state.config.prefix_max_chars),
		suffix = truncate_right(table.concat(after_lines, "\n"), state.config.suffix_max_chars),
	}, nil
end

local function record_accept(ctx, text)
	local short = text:gsub("\n", "\\n")
	short = truncate_right(short, 220)
	local item = {
		path = ctx.path,
		filetype = ctx.filetype,
		snippet = short,
		time = os.time(),
	}

	table.insert(state.accepted_history, 1, item)
	while #state.accepted_history > state.config.history_max_items do
		table.remove(state.accepted_history)
	end
	state.context_version = state.context_version + 1
end

local function capture_last_buffer_context(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	if vim.bo[bufnr].buftype ~= "" then
		return
	end

	local path = get_buf_path(bufnr)
	if not path then
		return
	end

	local count = vim.api.nvim_buf_line_count(bufnr)
	local start = math.max(0, count - state.config.last_buffer_tail_lines)
	local lines = vim.api.nvim_buf_get_lines(bufnr, start, count, false)
	local snippet = truncate_left(table.concat(lines, "\n"), state.config.last_buffer_max_chars)

	state.last_buffer_context = {
		path = path,
		filetype = vim.bo[bufnr].filetype,
		snippet = snippet,
	}
	state.context_version = state.context_version + 1
end

local function format_history_block()
	if #state.accepted_history == 0 then
		return "(none)"
	end

	local out = {}
	local max_items = math.min(state.config.history_in_prompt, #state.accepted_history)
	for i = 1, max_items do
		local h = state.accepted_history[i]
		table.insert(out, string.format("- [%s] %s", h.path, h.snippet))
	end
	return table.concat(out, "\n")
end

local function build_prompt(ctx)
	local blocks = {
		"You are a fill-in-the-middle inline coding completion engine.",
		"Return only the code to insert at <CURSOR>.",
		"Do not repeat existing prefix or suffix text.",
		"Prefer correct, context-aware completions; multiline output is allowed when needed.",
		"If no useful completion exists, return an empty string.",
		"",
		string.format("File: %s", ctx.path),
		string.format("Filetype: %s", ctx.filetype ~= "" and ctx.filetype or "plain"),
		"",
		"Recent accepted completions:",
		format_history_block(),
	}

	if state.last_buffer_context and state.last_buffer_context.path ~= ctx.path then
		table.insert(blocks, "")
		table.insert(blocks, string.format("Recent other buffer (%s, %s):", state.last_buffer_context.path,
			state.last_buffer_context.filetype ~= "" and state.last_buffer_context.filetype or "plain"))
		table.insert(blocks, state.last_buffer_context.snippet)
	end

	table.insert(blocks, "")
	table.insert(blocks, "<PREFIX>")
	table.insert(blocks, ctx.prefix)
	table.insert(blocks, "<CURSOR>")
	table.insert(blocks, "<SUFFIX>")
	table.insert(blocks, ctx.suffix)

	return table.concat(blocks, "\n")
end

local function seed_session_if_needed(cb)
	if state.seeded_session or not state.session_id then
		cb(true)
		return
	end

	local seed = {
		noReply = true,
		parts = {
			{
				type = "text",
				text = "Session role: Neovim inline completion assistant. Keep context focused on concise insert-at-cursor code suggestions.",
			},
		},
	}

	local endpoint = string.format("/session/%s/message?directory=%s", state.session_id, url_encode(state.session_root))
	request(endpoint, seed, function(ok)
		state.seeded_session = ok
		cb(ok)
	end, { method = "POST" })
end

local function create_session(root, cb)
	local endpoint = "/session?directory=" .. url_encode(root)
	request(endpoint, { title = "Neovim Inline Completion" }, function(ok, data)
		if not ok or type(data) ~= "table" or type(data.id) ~= "string" then
			cb(false)
			return
		end

		state.session_id = data.id
		state.session_root = root
		state.seeded_session = false
		state.session_request_count = 0
		seed_session_if_needed(cb)
	end, { method = "POST" })
end

local function ensure_session(root, cb)
	if not state.config.reuse_session then
		create_session(root, cb)
		return
	end

	local max_requests = state.config.session_max_requests
	if state.session_id and state.session_root == root and type(max_requests) == "number" and max_requests > 0 and state.session_request_count >= max_requests then
		debug_notify("session rotated to keep context fast")
		state.session_id = nil
		state.seeded_session = false
		state.session_request_count = 0
	end

	if state.session_id and state.session_root == root then
		seed_session_if_needed(cb)
		return
	end
	create_session(root, cb)
end

local function request_completion(force, opts)
	opts = opts or {}

	if not is_insert_mode() and not opts.allow_normal_mode then
		debug_notify("request skipped: not in insert mode")
		if force then
			notify("Enter insert mode before requesting completion", vim.log.levels.WARN)
		end
		return
	end

	local ctx, ctx_err = build_context(not force)
	if not ctx then
		debug_notify("request skipped: context unavailable: " .. tostring(ctx_err))
		if force then
			notify("Completion skipped: " .. tostring(ctx_err), vim.log.levels.WARN)
		end
		clear_suggestion()
		return
	end

	local signature = table.concat({
		ctx.path,
		tostring(ctx.row),
		tostring(ctx.col),
		tostring(ctx.changedtick),
		tostring(state.context_version),
		ctx.prefix,
		ctx.suffix,
	}, "\n::\n")
	if state.config.dedupe_same_signature and (not force) and (not opts.bypass_signature) and signature == state.last_signature then
		debug_notify("request skipped: same signature (dedupe enabled)")
		return
	end
	state.last_signature = signature

	abort_pending_request()
	state.request_seq = state.request_seq + 1
	local request_id = state.request_seq

	ensure_server(function(server_ok)
		if not server_ok then
			notify("OpenCode server is not reachable. Start it with: opencode serve --port 4096", vim.log.levels.WARN)
			return
		end

		ensure_session(ctx.root, function(session_ok)
			if not session_ok then
				notify("Failed to create OpenCode session", vim.log.levels.ERROR)
				return
			end

			local endpoint = string.format("/session/%s/message?directory=%s", state.session_id, url_encode(ctx.root))
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
							completion = {
								type = "string",
								description = "Exact text to insert at cursor",
							},
						},
						required = { "completion" },
						additionalProperties = false,
					},
				},
				parts = {
					{ type = "text", text = build_prompt(ctx) },
				},
			}

			request(endpoint, body, function(ok, data, err, status)
				state.pending_request = nil
				if request_id ~= state.request_seq then
					return
				end

				if not ok then
					if status == 404 then
						state.session_id = nil
						state.seeded_session = false
						state.last_signature = nil
						request_completion(force)
						return
					end
					if status == 0 then
						state.server_healthy = false
						state.last_health_check_ms = 0
					end
					notify("Completion request failed: " .. (err or "unknown error"), vim.log.levels.WARN)
					return
				end

				if type(data) ~= "table" then
					return
				end

				state.session_request_count = state.session_request_count + 1

				if data.info and data.info.error and data.info.error.message then
					notify("Model error: " .. data.info.error.message, vim.log.levels.WARN)
					return
				end

				local completion = extract_completion(data)
				if type(completion) ~= "string" then
					debug_notify("response has no text completion")
					clear_suggestion()
					return
				end

				completion = completion:gsub("\r\n", "\n")
				completion = completion:gsub("\r", "\n")
				completion = completion:gsub("^```[%w_-]*\n", "")
				completion = completion:gsub("\n```$", "")
				completion = normalize_tabs_with_context(completion, ctx)
				completion = truncate_right(completion, state.config.max_completion_chars)
				completion = trim_prefix_overlap(completion, ctx.prefix)
				completion = trim_completion_overlap(completion, ctx.suffix)

				set_suggestion(ctx, completion)
				if force and completion == "" then
					notify("No completion for current cursor context")
				end
				debug_notify("suggestion updated")
			end, { method = "POST", track_pending = true })
		end)
	end)
end

local function schedule_poll()
	if not is_insert_mode() then
		return
	end

	local ctx, reason = build_context(true)
	if not ctx then
		debug_notify("poll skipped: " .. tostring(reason))
		clear_timer()
		return
	end

	if not state.poll_timer then
		state.poll_timer = uv.new_timer()
	end

	state.poll_timer:stop()
	state.poll_timer:start(state.config.poll_delay_ms, 0, vim.schedule_wrap(function()
		request_completion(false)
	end))
end

local function insert_text_at_cursor(text)
	if text == "" then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]
	local lines = split_lines(text)

	vim.api.nvim_buf_set_text(bufnr, row, col, row, col, lines)

	local new_row = row
	local new_col = col
	if #lines == 1 then
		new_col = col + #lines[1]
	else
		new_row = row + #lines - 1
		new_col = #lines[#lines]
	end

	vim.api.nvim_win_set_cursor(0, { new_row + 1, new_col })
end

function M.accept()
	if not suggestion_is_still_valid() then
		clear_suggestion()
		return false
	end

	local ctx = build_context(false)
	local text = state.suggestion.text
	clear_suggestion()
	vim.schedule(function()
		local ok, err = pcall(insert_text_at_cursor, text)
		if not ok then
			notify("Failed to insert completion: " .. tostring(err), vim.log.levels.WARN)
			return
		end
		if ctx then
			record_accept(ctx, text)
		end
		schedule_poll()
	end)
	return true
end

function M.force_complete()
	request_completion(true)
end

function M.debug_snapshot()
	local ctx_auto, err_auto = build_context(true)
	local ctx_force, err_force = build_context(false)
	local lines = {
		"mode=" .. vim.api.nvim_get_mode().mode,
		"buftype=" .. vim.bo.buftype,
		"modifiable=" .. tostring(vim.bo.modifiable),
		"readonly=" .. tostring(vim.bo.readonly),
		"auto_context=" .. (ctx_auto and "yes" or ("no (" .. tostring(err_auto) .. ")")),
		"force_context=" .. (ctx_force and "yes" or ("no (" .. tostring(err_force) .. ")")),
		"session=" .. tostring(state.session_id or "none"),
		"session_requests=" .. tostring(state.session_request_count),
		"session_max_requests=" .. tostring(state.config.session_max_requests),
		"reuse_session=" .. tostring(state.config.reuse_session),
	}
	notify(table.concat(lines, " | "))
end

local function on_insert_activity()
	if state.suggestion and not suggestion_is_still_valid() then
		clear_suggestion()
	end
	schedule_poll()
end

local function tab_handler()
	if vim.fn.pumvisible() == 1 then
		return termcodes("<Tab>")
	end
	if M.accept() then
		return ""
	end
	return termcodes("<Tab>")
end

local function set_user_command(name, rhs)
	pcall(vim.api.nvim_del_user_command, name)
	vim.api.nvim_create_user_command(name, rhs, {})
end

function M.setup(opts)
	if state.initialized and not opts then
		return
	end

	state.config = tbl_deep_extend(vim.deepcopy(M.config), opts or {})
	state.initialized = true

	local group = vim.api.nvim_create_augroup("OpenCodeCopilot", { clear = true })

	vim.api.nvim_create_autocmd("InsertEnter", {
		group = group,
		callback = function()
			clear_timer()
			vim.schedule(function()
				request_completion(false, { allow_normal_mode = true, bypass_signature = true })
			end)
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
		group = group,
		callback = on_insert_activity,
	})

	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function()
			clear_timer()
			abort_pending_request()
			clear_suggestion()
		end,
	})

	vim.api.nvim_create_autocmd({ "BufLeave", "BufHidden" }, {
		group = group,
		callback = function(ev)
			capture_last_buffer_context(ev.buf)
		end,
	})

	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			clear_timer()
			abort_pending_request()
			if state.poll_timer and not state.poll_timer:is_closing() then
				state.poll_timer:close()
				state.poll_timer = nil
			end
		end,
	})

	if state.config.map_tab then
		vim.keymap.set("i", "<Tab>", tab_handler, {
			expr = true,
			silent = true,
			desc = "Accept OpenCode inline suggestion",
		})
	end

	for _, key in ipairs(state.config.manual_trigger_keys) do
		vim.keymap.set("i", key, function()
			M.force_complete()
		end, {
			silent = true,
			desc = "Force OpenCode inline completion",
		})
	end

	set_user_command("OpenCodeComplete", function()
		if not is_insert_mode() then
			vim.cmd("startinsert")
			vim.defer_fn(function()
				request_completion(true)
			end, 30)
			return
		end
		request_completion(true)
	end)

	set_user_command("OpenCodeAccept", function()
		M.accept()
	end)

	set_user_command("OpenCodeResetSession", function()
		state.session_id = nil
		state.session_root = nil
		state.seeded_session = false
		state.session_request_count = 0
		state.last_signature = nil
		state.context_version = state.context_version + 1
		notify("OpenCode completion session reset")
	end)

	set_user_command("OpenCodeStatus", function()
		ensure_server(function(ok)
			if not ok then
				notify("Server unavailable at " .. state.config.server_url, vim.log.levels.WARN)
				return
			end
			notify(string.format("Server OK (%s), session=%s, requests=%d", state.config.server_url, state.session_id or "none", state.session_request_count))
		end)
	end)

	set_user_command("OpenCodeDiag", function()
		M.debug_snapshot()
	end)
end

if vim.g.opencode_copilot_disable_auto_setup ~= 1 then
	M.setup()
end

return M
