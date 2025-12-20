-- vim_ai_gen.lua
-- Usage:
--   require("vim_ai_gen").setup()
--
-- ENV:
--   VIM_AI_KEY   (required)
--   VIM_MODEL    (default: "deepseek-chat")
--   VIM_BASE_URL (default: "https://api.deepseek.com/beta")
--
-- Keymaps (defaults):
--   <leader>G   - generate using only the metatag block
--   <leader>gb  - generate with whole buffer context
--   <leader>gf  - generate with buffer + directory listing next to file
--   <leader>gc  - generate with buffer + directory listing from Neovim CWD
--   :AIGenCancel
--
-- Metatags:
--   # @param x 2d array
--   # @return 2d array
--   # @note use jit
--   def foo(...):
--       ...
--   # @
--
-- IMPORTANT:
-- - Enforces "ONLY CODE" by requiring the model to call the tool `final_code({code: ...})`.
-- - If the model replies with chat text, we retry (strict mode).
--
-- Dependencies:
--   curl (required)
--   rg (optional; used by search_project tool)

local M = {}
local uv = vim.uv or vim.loop

-- ===================== CONFIG =====================
M.config = {
	streaming = true,

	-- Enforce "only code" by requiring the model to call final_code tool.
	enforce_code_only_via_tool = true,
	max_final_retries = 2,

	temperature = 0.2,
	max_tokens = 1024,
	max_buffer_chars = 120000,
	max_tool_steps = 12,

	keymaps = {
		block = "<leader>G",
		buffer = "<leader>gb",
		folder = "<leader>gf",
		codebase = "<leader>gc",
	},

	spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
	spinner_interval_ms = 85,
}

local FINAL_TOOL_NAME = "final_code"

-- ===================== UTILS =====================
local function notify(msg, level)
	vim.schedule(function()
		vim.notify(msg, level or vim.log.levels.INFO, { title = "AI Gen" })
	end)
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

local function json_encode(x)
	if vim.json and vim.json.encode then return vim.json.encode(x) end
	return vim.fn.json_encode(x)
end

local function json_decode(s)
	if vim.json and vim.json.decode then return vim.json.decode(s) end
	return vim.fn.json_decode(s)
end

local function system(cmd, opts)
	opts = opts or {}
	if vim.system then
		local res = vim.system(cmd, { cwd = opts.cwd, text = true }):wait()
		return res.code, res.stdout or "", res.stderr or ""
	end
	local parts = {}
	for _, c in ipairs(cmd) do table.insert(parts, vim.fn.shellescape(c)) end
	local line = table.concat(parts, " ")
	if opts.cwd and opts.cwd ~= "" then
		line = "cd " .. vim.fn.shellescape(opts.cwd) .. " && " .. line
	end
	local out = vim.fn.system(line)
	return vim.v.shell_error, out or "", ""
end

local function starts_with(s, prefix) return s:sub(1, #prefix) == prefix end
local function path_join(a, b)
	if a:sub(-1) == "/" then return a .. b end; return a .. "/" .. b
end

local function path_norm(p)
	local is_abs = p:sub(1, 1) == "/"
	local parts = {}
	for seg in string.gmatch(p, "[^/]+") do
		if seg == ".." then
			if #parts > 0 then table.remove(parts, #parts) end
		elseif seg ~= "." and seg ~= "" then
			table.insert(parts, seg)
		end
	end
	local out = table.concat(parts, "/")
	if is_abs then out = "/" .. out end
	if out == "" then out = is_abs and "/" or "." end
	return out
end

local function file_dir(path)
	if not path or path == "" then return uv.cwd() end
	local d = vim.fn.fnamemodify(path, ":h")
	if d == "." then return uv.cwd() end
	return d
end

local function is_dot_path(p)
	for seg in string.gmatch(p, "[^/]+") do
		if seg:sub(1, 1) == "." then return true end
	end
	return false
end

local function readable_file(path)
	local st = uv.fs_stat(path)
	return st and st.type == "file"
end

local function scandir(path)
	local handle = uv.fs_scandir(path)
	if not handle then return {} end
	local items = {}
	while true do
		local name, t = uv.fs_scandir_next(handle)
		if not name then break end
		table.insert(items, { name = name, type = t })
	end
	table.sort(items, function(x, y) return x.name < y.name end)
	return items
end

local function strip_code_fences(s)
	if not s then return "" end
	s = s:gsub("^%s*```[%w_-]*%s*\n", "")
	s = s:gsub("\n%s*```%s*$", "")
	return s
end

-- Extract partial JSON string value for key "code" from tool arguments being streamed.
-- This lets us "stream code" even though the model is emitting JSON arguments.
local function extract_partial_code_from_args(argstr)
	if type(argstr) ~= "string" or argstr == "" then return nil end

	local k = argstr:find('"code"%s*:%s*"', 1)
	if not k then return nil end
	local startq = argstr:find('"code"%s*:%s*"', 1)
	if not startq then return nil end

	local i = startq + #"\"code\": \"" -- approximate; safer to compute exact:
	do
		local s2, e2 = argstr:find('"code"%s*:%s*"', 1)
		if not e2 then return nil end
		i = e2 + 1
	end

	local out = {}
	local esc = false
	local j = i
	while j <= #argstr do
		local c = argstr:sub(j, j)
		if esc then
			if c == "n" then
				table.insert(out, "\n")
			elseif c == "r" then
				table.insert(out, "\r")
			elseif c == "t" then
				table.insert(out, "\t")
			elseif c == '"' then
				table.insert(out, '"')
			elseif c == "\\" then
				table.insert(out, "\\")
			elseif c == "b" then
				table.insert(out, "\b")
			elseif c == "f" then
				table.insert(out, "\f")
			elseif c == "u" then
				-- best effort: if \uXXXX complete, decode basic BMP hex to UTF-8
				local hex = argstr:sub(j + 1, j + 4)
				if hex:match("^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$") then
					local cp = tonumber(hex, 16)
					-- minimal utf8 encoding for cp <= 0xFFFF
					if cp <= 0x7F then
						table.insert(out, string.char(cp))
					elseif cp <= 0x7FF then
						table.insert(out, string.char(0xC0 + math.floor(cp / 0x40)))
						table.insert(out, string.char(0x80 + (cp % 0x40)))
					else
						table.insert(out, string.char(0xE0 + math.floor(cp / 0x1000)))
						table.insert(out, string.char(0x80 + (math.floor(cp / 0x40) % 0x40)))
						table.insert(out, string.char(0x80 + (cp % 0x40)))
					end
					j = j + 4
				else
					-- incomplete \u escape; stop early
					break
				end
			else
				-- unknown escape, keep char
				table.insert(out, c)
			end
			esc = false
		else
			if c == "\\" then
				esc = true
			elseif c == '"' then
				break -- end of string
			else
				table.insert(out, c)
			end
		end
		j = j + 1
	end

	return table.concat(out)
end

-- ===================== GIT HELPERS =====================
local git_cache = { root = nil, checked = false, ignore = {} }

local function detect_git_root(seed_dir)
	if git_cache.checked and git_cache.root then return git_cache.root end
	local function try(dir)
		local code, out = system({ "git", "-C", dir, "rev-parse", "--show-toplevel" })
		if code == 0 then
			local root = (out:gsub("%s+$", ""))
			if root ~= "" then return root end
		end
		return nil
	end
	local root = try(seed_dir) or try(uv.cwd())
	git_cache.root, git_cache.checked = root, true
	return root
end

local function is_gitignored(project_root, abs_path)
	if not project_root or project_root == "" then return false end
	local cached = git_cache.ignore[abs_path]
	if cached ~= nil then return cached end

	local rel = abs_path
	if starts_with(abs_path, project_root) then
		rel = abs_path:sub(#project_root + 2)
	end
	local code = system({ "git", "-C", project_root, "check-ignore", "-q", rel })
	local ignored = (code == 0)
	git_cache.ignore[abs_path] = ignored
	return ignored
end

-- ===================== NAMESPACES / HIGHLIGHTS =====================
local ns_tags  = vim.api.nvim_create_namespace("AI_GEN_TAGS")
local ns_marks = vim.api.nvim_create_namespace("AI_GEN_MARKS")
local ns_hl    = vim.api.nvim_create_namespace("AI_GEN_HL")
local ns_spin  = vim.api.nvim_create_namespace("AI_GEN_SPINNER")

local function setup_highlights()
	vim.api.nvim_set_hl(0, "AIGenTagLine", { link = "SpecialComment" })
	vim.api.nvim_set_hl(0, "AIGenTagName", { link = "Keyword" })
	vim.api.nvim_set_hl(0, "AIGenRegion", { link = "Visual" })
	vim.api.nvim_set_hl(0, "AIGenGhost", { link = "Comment" })
end

-- ===================== METATAGS =====================
local function comment_leader_for_buf(bufnr)
	local ft = vim.bo[bufnr].filetype
	local map = {
		lua = "---",
		python = "#",
		sh = "#",
		bash = "#",
		zsh = "#",
		ruby = "#",
		perl = "#",
		c = "//",
		cpp = "//",
		objc = "//",
		objcpp = "//",
		java = "//",
		javascript = "//",
		typescript = "//",
		javascriptreact = "//",
		typescriptreact = "//",
		go = "//",
		rust = "//",
		swift = "//",
		kotlin = "//",
		zig = "//",
		cs = "//",
		php = "//",
	}
	if map[ft] then return map[ft] end

	local cs = vim.bo[bufnr].commentstring or ""
	if cs:find("%%s") then
		local prefix = cs:match("^(.-)%%s") or ""
		prefix = prefix:gsub("%s+$", "")
		if prefix ~= "" then
			if prefix:find("/%*") then return "//" end
			return prefix
		end
	end
	return "---"
end

local function tag_line_info(bufnr, line)
	local leader = comment_leader_for_buf(bufnr)
	local esc = vim.pesc(leader)
	local rest = line:match("^%s*" .. esc .. "%s*@%s*(.*)$")
	if not rest then return nil end
	rest = rest or ""
	local name = rest:match("^([%w_%-]+)")
	local is_empty = (rest:gsub("%s+", "") == "")
	local at_col = (line:find("@", 1, true) or 1) - 1
	return { leader = leader, rest = rest, tag = name, empty = is_empty, col = at_col }
end

local function refresh_tag_highlights(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then return end
	vim.api.nvim_buf_clear_namespace(bufnr, ns_tags, 0, -1)

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for i, line in ipairs(lines) do
		local info = tag_line_info(bufnr, line)
		if info then
			local row = i - 1
			vim.api.nvim_buf_set_extmark(bufnr, ns_tags, row, 0, {
				hl_group = "AIGenTagLine",
				end_row = row,
				end_col = #line,
			})
			local taglen = 1
			if info.tag then taglen = 1 + #info.tag end
			vim.api.nvim_buf_set_extmark(bufnr, ns_tags, row, info.col, {
				hl_group = "AIGenTagName",
				end_row = row,
				end_col = math.min(#line, info.col + taglen),
			})
		end
	end
end

local function find_block(bufnr, cursor_row)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local n = #lines
	if n == 0 then return nil, "Empty buffer" end

	local function is_tag_row(r)
		if r < 0 or r >= n then return false end
		return tag_line_info(bufnr, lines[r + 1]) ~= nil
	end
	local function is_empty_tag_row(r)
		if r < 0 or r >= n then return false end
		local info = tag_line_info(bufnr, lines[r + 1])
		return info and info.empty
	end

	local anchor
	for r = cursor_row, 0, -1 do
		if is_tag_row(r) then
			anchor = r; break
		end
	end
	if not anchor then return nil, "No metatag comment found above cursor" end

	local header_top = anchor
	while header_top - 1 >= 0 do
		if not is_tag_row(header_top - 1) then break end
		if is_empty_tag_row(header_top - 1) then break end
		header_top = header_top - 1
	end

	local header_bottom = header_top
	while header_bottom < n do
		if not is_tag_row(header_bottom) then break end
		if is_empty_tag_row(header_bottom) then break end
		header_bottom = header_bottom + 1
	end

	local code_start = header_bottom
	local end_marker
	for r = code_start, n - 1 do
		if is_empty_tag_row(r) then
			end_marker = r; break
		end
	end
	if not end_marker then return nil, "No closing empty '@' metatag found below header" end

	return {
		header_top = header_top,
		header_bottom = header_bottom,
		code_start = code_start,
		end_marker = end_marker,
		header_lines = vim.api.nvim_buf_get_lines(bufnr, header_top, header_bottom, false),
		code_lines = vim.api.nvim_buf_get_lines(bufnr, code_start, end_marker, false),
	}
end

local function parse_includes(header_lines)
	local includes = {}
	for _, l in ipairs(header_lines) do
		local m = l:match("@%s*include%s+(.+)$")
		if m then
			m = m:gsub("%s+$", "")
			table.insert(includes, m)
		end
	end
	return includes
end

-- ===================== INLINE SPINNER =====================
local Spinner = {}
Spinner.__index = Spinner

function Spinner.new(bufnr, row)
	return setmetatable({
		bufnr = bufnr,
		row = row,
		timer = nil,
		frame = 1,
		running = false,
		msg = "Thinking",
	}, Spinner)
end

function Spinner:_render()
	if not vim.api.nvim_buf_is_valid(self.bufnr) then return end
	vim.api.nvim_buf_clear_namespace(self.bufnr, ns_spin, self.row, self.row + 1)
	local f = M.config.spinner_frames[self.frame]
	vim.api.nvim_buf_set_extmark(self.bufnr, ns_spin, self.row, 0, {
		virt_text = { { ("%s %s"):format(f, self.msg), "AIGenGhost" } },
		virt_text_pos = "overlay",
		hl_mode = "blend",
	})
end

function Spinner:start(msg)
	self.msg = msg or self.msg
	self.running = true
	self.frame = 1
	self:_render()

	self.timer = uv.new_timer()
	self.timer:start(0, M.config.spinner_interval_ms, function()
		vim.schedule(function()
			if not self.running then return end
			self.frame = (self.frame % #M.config.spinner_frames) + 1
			self:_render()
		end)
	end)
end

function Spinner:set_status(msg)
	self.msg = msg or self.msg
end

function Spinner:stop()
	self.running = false
	if self.timer then
		pcall(function() self.timer:stop() end)
		pcall(function() self.timer:close() end)
		self.timer = nil
	end
	if vim.api.nvim_buf_is_valid(self.bufnr) then
		vim.api.nvim_buf_clear_namespace(self.bufnr, ns_spin, self.row, self.row + 1)
	end
end

-- ===================== REGION MARKS / HL =====================
local function highlight_region(bufnr, start_row, end_row)
	vim.api.nvim_buf_clear_namespace(bufnr, ns_hl, 0, -1)
	if start_row >= end_row then return end
	vim.api.nvim_buf_set_extmark(bufnr, ns_hl, start_row, 0, {
		hl_group = "AIGenRegion",
		end_row = end_row,
		end_col = 0,
	})
end

local function clear_region_ui(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, ns_hl, 0, -1)
end

local function get_mark_row(bufnr, id)
	local pos = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns_marks, id, {})
	return pos and pos[1] or nil
end

local function replace_region(bufnr, start_mark_id, end_mark_id, text)
	local sr = get_mark_row(bufnr, start_mark_id)
	local er = get_mark_row(bufnr, end_mark_id)
	if not sr or not er then return false end

	text = (text or ""):gsub("\r\n", "\n")
	local lines = {}
	for l in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, l) end
	if #lines > 0 and lines[#lines] == "" then table.remove(lines, #lines) end

	vim.api.nvim_buf_set_lines(bufnr, sr, er, false, lines)
	return true
end

local function stream_update_region(bufnr, start_mark_id, end_mark_id, acc_text, first)
	local sr = get_mark_row(bufnr, start_mark_id)
	local er = get_mark_row(bufnr, end_mark_id)
	if not sr or not er then return false end

	local text = (acc_text or ""):gsub("\r\n", "\n")
	local lines = {}
	for l in (text .. "\n"):gmatch("(.-)\n") do table.insert(lines, l) end
	if #lines > 0 and lines[#lines] == "" then table.remove(lines, #lines) end

	vim.api.nvim_buf_call(bufnr, function()
		if not first then pcall(vim.cmd, "silent! undojoin") end
		vim.api.nvim_buf_set_lines(bufnr, sr, er, false, lines)
	end)
	return true
end

-- ===================== TOOLS =====================
local function resolve_path(ctx, p)
	if not p or p == "" then return nil, "Empty path" end
	if is_dot_path(p) then return nil, "Dotfiles are not allowed" end

	local abs
	if p:sub(1, 1) == "/" then
		abs = path_norm(p)
	else
		abs = path_norm(path_join(ctx.base_dir, p))
	end

	local pr = ctx.project_root
	if pr and pr ~= "" then
		local prn = path_norm(pr)
		if not starts_with(abs, prn) then
			return nil, ("Path escapes project root: %s"):format(abs)
		end
	end

	return abs, nil
end

local function tool_list_dir(ctx, args)
	local abs, err = resolve_path(ctx, args.path)
	if err then return nil, err end
	local st = uv.fs_stat(abs)
	if not st or st.type ~= "directory" then return nil, "Not a directory: " .. abs end

	local max_entries = tonumber(args.max_entries or 200) or 200
	local items = scandir(abs)
	local out = {}

	for _, it in ipairs(items) do
		if #out >= max_entries then break end
		if it.name:sub(1, 1) ~= "." then
			local child_abs = path_join(abs, it.name)
			if not is_gitignored(ctx.project_root, child_abs) then
				table.insert(out, { name = it.name, type = it.type })
			end
		end
	end
	return { path = abs, entries = out }, nil
end

local function tool_read_file(ctx, args)
	local abs, err = resolve_path(ctx, args.path)
	if err then return nil, err end
	if not readable_file(abs) then return nil, "Not a readable file: " .. abs end
	if is_gitignored(ctx.project_root, abs) then return nil, "File is gitignored: " .. abs end

	local max_bytes = tonumber(args.max_bytes or 200000) or 200000
	local fd = uv.fs_open(abs, "r", 438)
	if not fd then return nil, "Failed to open file: " .. abs end
	local stat = uv.fs_fstat(fd)
	local size = math.min(stat.size or max_bytes, max_bytes)
	local data = uv.fs_read(fd, size, 0) or ""
	uv.fs_close(fd)
	return { path = abs, bytes = #data, content = data }, nil
end

local function tool_search_project(ctx, args)
	if vim.fn.executable("rg") ~= 1 then
		return nil, "ripgrep (rg) not found in PATH"
	end
	local q = args.query
	if not q or q == "" then return nil, "Empty query" end
	local max_results = tonumber(args.max_results or 120) or 120

	local code, out = system({
		"rg", "--no-heading", "--with-filename", "--line-number", "--column",
		"--max-count", tostring(max_results),
		q,
	}, { cwd = ctx.project_root or ctx.base_dir })

	if code ~= 0 and code ~= 1 then
		return nil, ("rg failed (code %d): %s"):format(code, out:gsub("%s+$", ""))
	end

	local lines = {}
	for l in out:gmatch("[^\n]+") do table.insert(lines, l) end
	return { query = q, results = lines }, nil
end

local function dispatch_tool(ctx, name, args)
	if name == "list_dir" then return tool_list_dir(ctx, args) end
	if name == "read_file" then return tool_read_file(ctx, args) end
	if name == "search_project" then return tool_search_project(ctx, args) end
	return nil, "Unknown tool: " .. tostring(name)
end

local function make_tool_schemas()
	local tools = {
		{
			type = "function",
			["function"] = {
				name = "list_dir",
				description =
				"List directory entries (files and folders) for a path. Excludes dotfiles and gitignored entries. Paths are relative to the project root unless absolute.",
				parameters = {
					type = "object",
					properties = {
						path = { type = "string" },
						max_entries = { type = "integer", default = 200 },
					},
					required = { "path" },
					additionalProperties = false,
				},
			},
		},
		{
			type = "function",
			["function"] = {
				name = "read_file",
				description =
				"Read a UTF-8 text file. Excludes dotfiles and gitignored files. Paths are relative to the project root unless absolute.",
				parameters = {
					type = "object",
					properties = {
						path = { type = "string" },
						max_bytes = { type = "integer", default = 200000 },
					},
					required = { "path" },
					additionalProperties = false,
				},
			},
		},
		{
			type = "function",
			["function"] = {
				name = "search_project",
				description =
				"Search project text using ripgrep (rg). Returns filename:line:col:match. Respects .gitignore.",
				parameters = {
					type = "object",
					properties = {
						query = { type = "string" },
						max_results = { type = "integer", default = 120 },
					},
					required = { "query" },
					additionalProperties = false,
				},
			},
		},
	}

	if M.config.enforce_code_only_via_tool then
		table.insert(tools, {
			type = "function",
			["function"] = {
				name = FINAL_TOOL_NAME,
				description =
				"FINAL RESPONSE. Return ONLY the code to insert into the marked region. No prose, no markdown AND NO COMMENTS.",
				parameters = {
					type = "object",
					properties = {
						code = { type = "string", description = "The exact code to insert into the region." },
					},
					required = { "code" },
					additionalProperties = false,
				},
			},
		})
	end

	return tools
end

-- ===================== PROMPTS / ENV =====================
local function build_system_prompt()
	local lines = {
		"You are a code-generation assistant integrated into Neovim.",
		"",
		"The user marks a code region using metatag comment lines that contain '@'.",
		"Metatags appear as contiguous comment lines (the 'header') above a code region.",
		"The code region ends at the next empty tag line (a comment line that is just '@' with optional spaces).",
		"",
		"Supported metatags:",
		"  @param <name> <type>",
		"  @return <type>",
		"  @note <text>",
		"  @include <path>",
		"  @   (empty tag: closing marker)",
		"",
		"When you write code you DO NOT use any comments for explanations.",
	}

	if M.config.enforce_code_only_via_tool then
		table.insert(lines, "CRITICAL OUTPUT RULE:")
		table.insert(lines,
			("- When you are ready to output the final code, you MUST call the tool '%s' with {\"code\": \"...\"}.")
			:format(FINAL_TOOL_NAME))
		table.insert(lines,
			"- Do NOT write normal chat text. Do NOT use markdown fences. The final output must be ONLY the tool call.")
		table.insert(lines, "")
	else
		table.insert(lines,
			"Output ONLY the code that should live inside the code region. No markdown fences, no explanations.")
		table.insert(lines, "")
	end

	table.insert(lines, "Tools are available for reading files and listing directories if you need more context.")

	return table.concat(lines, "\n")
end

local function get_env_cfg()
	local key = vim.env.VIM_AI_KEY
	if not key or key == "" then return nil, "Missing VIM_AI_KEY" end

	local model = vim.env.VIM_MODEL
	if not model or model == "" then model = "deepseek-chat" end

	local base = vim.env.VIM_BASE_URL
	if not base or base == "" then base = "https://api.deepseek.com/beta" end
	base = base:gsub("/+$", "")

	return { key = key, model = model, url = base .. "/chat/completions" }, nil
end

local function make_ctx(mode, bufnr)
	local filepath = vim.api.nvim_buf_get_name(bufnr)
	local bufdir = file_dir(filepath)
	local cwd = uv.cwd()
	local git_root = detect_git_root(bufdir) or detect_git_root(cwd)
	local base_dir = (mode == "gc") and cwd or bufdir
	local project_root = git_root or base_dir
	return {
		mode = mode,
		filepath = filepath,
		filetype = vim.bo[bufnr].filetype,
		base_dir = base_dir,
		project_root = project_root,
	}
end

local function initial_dir_snapshot(ctx, p)
	local st = uv.fs_stat(p)
	if not st or st.type ~= "directory" then return "" end
	local items = scandir(p)
	local names = {}
	for _, it in ipairs(items) do
		if it.name:sub(1, 1) ~= "." then
			local abs = path_join(p, it.name)
			if not is_gitignored(ctx.project_root, abs) then
				table.insert(names, (it.type == "directory" and (it.name .. "/") or it.name))
			end
		end
	end
	return table.concat(names, "\n")
end

local function build_user_prompt(ctx, block, bufnr)
	local prompt = {}
	table.insert(prompt, ("File: %s"):format(ctx.filepath ~= "" and ctx.filepath or "(unnamed buffer)"))
	table.insert(prompt, ("Filetype: %s"):format(ctx.filetype))
	table.insert(prompt, "")
	table.insert(prompt, "Metatag header:")
	table.insert(prompt, table.concat(block.header_lines, "\n"))
	table.insert(prompt, "")
	table.insert(prompt, "Current code region:")
	table.insert(prompt, table.concat(block.code_lines, "\n"))
	table.insert(prompt, "")
	table.insert(prompt, "Task: generate the correct replacement code for the code region.")

	if ctx.mode == "gb" or ctx.mode == "gf" or ctx.mode == "gc" then
		local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local whole = table.concat(buf_lines, "\n")
		if #whole > M.config.max_buffer_chars then
			whole = whole:sub(1, M.config.max_buffer_chars) .. "\n\n[TRUNCATED]\n"
		end
		table.insert(prompt, "")
		table.insert(prompt, "Full buffer context:")
		table.insert(prompt, whole)
	end

	if ctx.mode == "gf" then
		table.insert(prompt, "")
		table.insert(prompt, ("Directory listing near file: %s"):format(ctx.base_dir))
		table.insert(prompt, initial_dir_snapshot(ctx, ctx.base_dir))
	elseif ctx.mode == "gc" then
		table.insert(prompt, "")
		table.insert(prompt, ("Project listing from CWD: %s"):format(ctx.base_dir))
		table.insert(prompt, initial_dir_snapshot(ctx, ctx.base_dir))
	end

	-- Eager @include
	local includes = parse_includes(block.header_lines)
	if #includes > 0 then
		table.insert(prompt, "")
		table.insert(prompt, "Additional content from @include:")
		for _, inc in ipairs(includes) do
			table.insert(prompt, "")
			table.insert(prompt, ("--- %s"):format(inc))
			local res, err = tool_read_file(ctx, { path = inc, max_bytes = 200000 })
			if err then
				table.insert(prompt, ("[include error] %s"):format(err))
			else
				table.insert(prompt, res.content)
			end
		end
	end

	return table.concat(prompt, "\n")
end

-- ===================== CURL / STREAM =====================
local active_job = nil
function M.cancel()
	if active_job then
		pcall(vim.fn.jobstop, active_job)
		active_job = nil
		notify("Cancelled active AI request", vim.log.levels.WARN)
	end
end

local function curl_post(url, api_key, body_json, stream, on_chunk, on_done)
	if vim.fn.executable("curl") ~= 1 then
		on_done(false, "curl not found in PATH")
		return
	end

	local args = {
		"curl", "-sS", "-X", "POST",
		"-H", "Content-Type: application/json",
		"-H", "Authorization: Bearer " .. api_key,
	}
	if stream then
		table.insert(args, "-N")
		table.insert(args, "--no-buffer")
	end
	table.insert(args, url)
	table.insert(args, "-d")
	table.insert(args, body_json)

	local stdout_accum = {}
	local job = vim.fn.jobstart(args, {
		stdout_buffered = not stream,
		stderr_buffered = true,
		on_stdout = function(_, data, _)
			if not data then return end
			if stream then
				for _, s in ipairs(data) do
					if s and s ~= "" then on_chunk(s) end
				end
			else
				for _, s in ipairs(data) do
					if s and s ~= "" then table.insert(stdout_accum, s) end
				end
			end
		end,
		on_stderr = function(_, data, _)
			if not data then return end
			for _, s in ipairs(data) do
				if s and s ~= "" then table.insert(stdout_accum, "[stderr] " .. s) end
			end
		end,
		on_exit = function(_, code, _)
			active_job = nil
			if stream then
				on_done(code == 0, code == 0 and nil or ("curl exited " .. tostring(code)))
			else
				local joined = table.concat(stdout_accum, "\n")
				on_done(code == 0, code == 0 and joined or joined)
			end
		end,
	})

	if job <= 0 then
		on_done(false, "Failed to start curl job")
		return
	end
	active_job = job
end

-- SSE line handling (tolerate partial frames)
local function make_sse_parser(on_data)
	local buf = ""
	return function(chunk)
		buf = buf .. chunk .. "\n"
		while true do
			local nl = buf:find("\n")
			if not nl then break end
			local line = buf:sub(1, nl - 1)
			buf = buf:sub(nl + 1)
			local data = line:match("^data:%s*(.*)$")
			if data then on_data(data) end
		end
	end
end

-- ===================== CHAT LOOP =====================
local function make_body(cfg, messages, tools, stream)
	return {
		model = cfg.model,
		messages = messages,
		tools = tools,
		tool_choice = "auto",
		temperature = M.config.temperature,
		stream = stream and true or false,
		max_tokens = M.config.max_tokens,
	}
end

local function parse_tool_calls_from_message(msg)
	local tcs = msg and msg.tool_calls
	if tcs and #tcs > 0 then return tcs end
	return nil
end

local function decode_tool_args(argstr)
	local ok, args = pcall(json_decode, argstr or "{}")
	if ok and type(args) == "table" then return args end
	return nil
end

local function strict_retry(messages, reason, attempt)
	if attempt > (M.config.max_final_retries or 0) then
		return false
	end
	table.insert(messages, {
		role = "user",
		content = ("Your last response violated the output rule (%s). You MUST call the tool '%s' with JSON arguments {\"code\": \"...\"}. No chat text.")
			:format(reason, FINAL_TOOL_NAME),
	})
	return true
end

local function chat_loop(spinner, ctx, cfg, messages, bufnr, start_mark_id, end_mark_id, stream)
	local tools = make_tool_schemas()
	local max_steps = M.config.max_tool_steps

	local function do_request(step, strict_attempt)
		strict_attempt = strict_attempt or 0
		if step > max_steps then
			spinner:stop()
			notify("Tool loop exceeded max steps", vim.log.levels.ERROR)
			clear_region_ui(bufnr)
			return
		end

		local body_json = json_encode(make_body(cfg, messages, tools, stream))

		-- ========== NON-STREAM ==========
		if not stream then
			spinner:set_status("Thinking")
			curl_post(cfg.url, cfg.key, body_json, false, function(_) end, function(ok, payload_or_err)
				spinner:stop()
				if not ok then
					notify(tostring(payload_or_err), vim.log.levels.ERROR)
					clear_region_ui(bufnr)
					return
				end

				local okj, obj = pcall(json_decode, payload_or_err)
				if not okj or not obj then
					notify("Invalid JSON response from API", vim.log.levels.ERROR)
					clear_region_ui(bufnr)
					return
				end
				if obj.error then
					notify("API error: " .. tostring(obj.error.message or "unknown"),
						vim.log.levels.ERROR)
					clear_region_ui(bufnr)
					return
				end

				local choice = obj.choices and obj.choices[1]
				local msg = choice and choice.message or {}
				local tool_calls = parse_tool_calls_from_message(msg)

				if tool_calls and #tool_calls > 0 then
					-- If final_code is present, end immediately by inserting args.code
					for _, call in ipairs(tool_calls) do
						local tname = call["function"] and call["function"].name
						if tname == FINAL_TOOL_NAME then
							local argstr = call["function"] and call["function"].arguments or
								"{}"
							local args = decode_tool_args(argstr)
							local code = args and args.code
							if type(code) ~= "string" then
								if M.config.enforce_code_only_via_tool and strict_retry(messages, "final_code missing 'code' string", strict_attempt + 1) then
									spinner:start("Thinking")
									do_request(step + 1, strict_attempt + 1)
									return
								end
								notify("final_code tool call missing code",
									vim.log.levels.ERROR)
								clear_region_ui(bufnr)
								return
							end
							replace_region(bufnr, start_mark_id, end_mark_id, code)
							clear_region_ui(bufnr)
							return
						end
					end

					-- otherwise, execute non-final tools
					table.insert(messages, msg)
					for _, call in ipairs(tool_calls) do
						local tname = call["function"] and call["function"].name
						local argstr = call["function"] and call["function"].arguments or "{}"
						local call_id = call.id

						spinner:start(("Tool: %s"):format(tname or "?"))

						local args = decode_tool_args(argstr) or {}
						local res, err = dispatch_tool(ctx, tname, args)
						if err then res = { error = err } end

						table.insert(messages, {
							role = "tool",
							tool_call_id = call_id,
							content = json_encode(res),
						})

						spinner:stop()
					end

					spinner:start("Thinking")
					do_request(step + 1, strict_attempt)
					return
				end

				-- No tool calls
				local content = msg.content or ""

				if M.config.enforce_code_only_via_tool then
					if strict_retry(messages, "assistant returned chat text instead of final_code tool call", strict_attempt + 1) then
						spinner:start("Thinking")
						do_request(step + 1, strict_attempt + 1)
						return
					end
					notify("Model refused to call final_code tool (strict mode).",
						vim.log.levels.ERROR)
					clear_region_ui(bufnr)
					return
				end

				-- fallback non-strict: treat content as code
				replace_region(bufnr, start_mark_id, end_mark_id, strip_code_fences(content))
				clear_region_ui(bufnr)
			end)
			return
		end

		-- ========== STREAM ==========
		spinner:set_status("Thinking")
		local tool_acc = {} -- index -> toolcall object
		local any_tool_missing_id = false
		local streamed_any_code = false
		local first_write = true

		local function sse_on_data(data)
			if data == "[DONE]" then return end
			local okj, obj = pcall(json_decode, data)
			if not okj or not obj then return end

			local ch = obj.choices and obj.choices[1]
			if not ch then return end
			local delta = ch.delta or {}

			-- If the model emits chat content while strict is on, ignore it.
			-- (We only accept final_code tool call.)
			if (not M.config.enforce_code_only_via_tool) and delta.content then
				-- Optional: could stream raw text as code in non-strict mode.
				streamed_any_code = true
				if spinner.running then spinner:stop() end
				-- NOTE: you'd need an accumulator for content; omitted here for clarity.
			end

			-- Tool call deltas (streaming)
			if delta.tool_calls then
				for _, tc in ipairs(delta.tool_calls) do
					local idx = tc.index or 0
					tool_acc[idx] = tool_acc[idx] or {
						id = tc.id,
						type = tc.type or "function",
						["function"] = { name = nil, arguments = "" },
						index = idx,
					}
					if tc.id then tool_acc[idx].id = tc.id end
					if not tool_acc[idx].id then
						-- some servers omit id in streaming; we will fallback to non-stream if we need to send tool results
						any_tool_missing_id = true
					end

					if tc["function"] then
						if tc["function"].name then
							tool_acc[idx]["function"].name = tc
								["function"].name
						end
						if tc["function"].arguments then
							tool_acc[idx]["function"].arguments = (tool_acc[idx]["function"].arguments or "") ..
								tc["function"].arguments
							-- If this is final_code, stream partial code into region
							if tool_acc[idx]["function"].name == FINAL_TOOL_NAME then
								local partial = extract_partial_code_from_args(tool_acc
									[idx]["function"].arguments)
								if partial and partial ~= "" then
									streamed_any_code = true
									if spinner.running then spinner:stop() end
									vim.schedule(function()
										stream_update_region(bufnr, start_mark_id,
											end_mark_id, partial, first_write)
										first_write = false
									end)
								end
							end
						end
					end
				end
			end
		end

		local feed = make_sse_parser(sse_on_data)

		curl_post(cfg.url, cfg.key, body_json, true, function(chunk)
			feed(chunk)
		end, function(ok, err)
			spinner:stop()
			if not ok then
				notify(tostring(err), vim.log.levels.ERROR)
				clear_region_ui(bufnr)
				return
			end

			-- collect calls in order
			local calls = {}
			for _, v in pairs(tool_acc) do
				if v and v["function"] and v["function"].name then
					table.insert(calls, v)
				end
			end
			table.sort(calls, function(a, b) return (a.index or 0) < (b.index or 0) end)

			-- If final_code exists -> apply and finish
			for _, call in ipairs(calls) do
				if call["function"].name == FINAL_TOOL_NAME then
					local args = decode_tool_args(call["function"].arguments or "{}")
					local code = args and args.code
					if type(code) ~= "string" then
						if M.config.enforce_code_only_via_tool and strict_retry(messages, "final_code invalid JSON or missing code", strict_attempt + 1) then
							spinner:start("Thinking")
							do_request(step + 1, strict_attempt + 1)
							return
						end
						notify("final_code invalid/missing code", vim.log.levels.ERROR)
						clear_region_ui(bufnr)
						return
					end
					replace_region(bufnr, start_mark_id, end_mark_id, code)
					clear_region_ui(bufnr)
					return
				end
			end

			-- If we have tool calls that are not final, we must execute them and re-call the model.
			if #calls > 0 then
				-- If IDs are missing and we need to respond with tool_call_id, fall back to non-stream for this step
				if any_tool_missing_id then
					-- Re-run same step non-stream to get proper tool_call ids
					spinner:start("Thinking")
					chat_loop(spinner, ctx, cfg, messages, bufnr, start_mark_id, end_mark_id, false)
					return
				end

				table.insert(messages, { role = "assistant", content = nil, tool_calls = calls })

				for _, call in ipairs(calls) do
					local tname = call["function"].name
					local argstr = call["function"].arguments or "{}"
					spinner:start(("Tool: %s"):format(tname))

					local args = decode_tool_args(argstr) or {}
					local res, terr = dispatch_tool(ctx, tname, args)
					if terr then res = { error = terr } end

					table.insert(messages, {
						role = "tool",
						tool_call_id = call.id,
						content = json_encode(res),
					})

					spinner:stop()
				end

				spinner:start("Thinking")
				do_request(step + 1, strict_attempt)
				return
			end

			-- No tool calls at all -> strict retry or fail
			if M.config.enforce_code_only_via_tool then
				if strict_retry(messages, "no tool call returned", strict_attempt + 1) then
					spinner:start("Thinking")
					do_request(step + 1, strict_attempt + 1)
					return
				end
				notify("Model returned no tool calls (strict mode).", vim.log.levels.ERROR)
				clear_region_ui(bufnr)
				return
			end

			-- Non-strict: nothing to do
			clear_region_ui(bufnr)
		end)
	end

	do_request(1, 0)
end

-- ===================== ENTRY =====================
function M.generate(mode)
	mode = mode or "block"
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	local cfg, err = get_env_cfg()
	if err then
		notify(err, vim.log.levels.ERROR); return
	end

	local block, berr = find_block(bufnr, row)
	if berr then
		notify(berr, vim.log.levels.ERROR); return
	end

	local ctx = make_ctx(mode, bufnr)

	-- region marks
	vim.api.nvim_buf_clear_namespace(bufnr, ns_marks, 0, -1)
	local start_mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_marks, block.code_start, 0,
		{ right_gravity = false })
	local end_mark_id   = vim.api.nvim_buf_set_extmark(bufnr, ns_marks, block.end_marker, 0, { right_gravity = true })

	highlight_region(bufnr, block.code_start, block.end_marker)

	local spinner = Spinner.new(bufnr, block.code_start)
	spinner:start("Thinking")

	local system_msg = { role = "system", content = build_system_prompt() }
	local user_msg = { role = "user", content = build_user_prompt(ctx, block, bufnr) }
	local messages = { system_msg, user_msg }

	chat_loop(spinner, ctx, cfg, messages, bufnr, start_mark_id, end_mark_id, M.config.streaming)
end

-- ===================== SETUP =====================
function M.setup(opts)
	if opts then tbl_deep_extend(M.config, opts) end
	setup_highlights()

	vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "TextChanged", "TextChangedI", "InsertLeave" }, {
		callback = function(ev) pcall(refresh_tag_highlights, ev.buf) end,
	})

	local km = M.config.keymaps
	vim.keymap.set("n", km.block, function() M.generate("block") end, { desc = "AI Gen: metatag block" })
	vim.keymap.set("n", km.buffer, function() M.generate("gb") end, { desc = "AI Gen: block + whole buffer" })
	vim.keymap.set("n", km.folder, function() M.generate("gf") end, { desc = "AI Gen: buffer + folder listing" })
	vim.keymap.set("n", km.codebase, function() M.generate("gc") end, { desc = "AI Gen: buffer + codebase listing" })

	vim.api.nvim_create_user_command("AIGenCancel", function() M.cancel() end, {})
end

return M
