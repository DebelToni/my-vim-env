-- Dependency-free align command for Neovim.
--
-- Usage:
--   1) In init.lua: require("align").setup()
--   2) Visual select lines, then:
--        :'<,'>align /-->/
--
-- What it does:
--   Aligns the first match of a Vim-regex pattern across the selected range by
--   inserting spaces immediately before the match so all matches begin at the
--   same *display* column (tabs accounted for via strdisplaywidth).

local M = {}

local function strip_wrapping_delims(arg)
	-- Accept /pattern/ or just pattern
	if not arg or arg == "" then
		return nil
	end

	local first = arg:sub(1, 1)
	local last = arg:sub(-1)

	-- If it looks like it's wrapped with a non-alnum delimiter (/,|,#,~, etc), strip it.
	if #arg >= 2 and first == last and not first:match("[%w]") then
		return arg:sub(2, -2)
	end

	return arg
end

local function align_range(opts)
	local pattern = strip_wrapping_delims(opts.args)
	if not pattern or pattern == "" then
		vim.notify("align: missing pattern. Example: :'<,'>align /-->/", vim.log.levels.ERROR)
		return
	end

	local ok, re = pcall(vim.regex, pattern)
	if not ok or not re then
		vim.notify(("align: invalid Vim regex: %s"):format(pattern), vim.log.levels.ERROR)
		return
	end

	local line1, line2 = opts.line1, opts.line2

	-- Pass 1: find maximum display width of prefix up to match start.
	local max_prefix_w = 0
	local hits = {}

	for lnum = line1, line2 do
		local line = vim.fn.getline(lnum)
		local s = re:match_str(line) -- 0-based byte index where match starts, or nil
		if s ~= nil then
			local prefix = line:sub(1, s) -- s==0 => ""
			local w = vim.fn.strdisplaywidth(prefix)
			if w > max_prefix_w then
				max_prefix_w = w
			end
			hits[#hits + 1] = { lnum = lnum, line = line, s = s, w = w }
		end
	end

	if #hits == 0 then
		vim.notify(("align: no matches for /%s/ in the selected range"):format(pattern), vim.log.levels.WARN)
		return
	end

	-- Pass 2: insert spaces so match start aligns to max_prefix_w.
	for _, h in ipairs(hits) do
		local pad = max_prefix_w - h.w
		if pad > 0 then
			local before = h.line:sub(1, h.s)
			local after = h.line:sub(h.s + 1)
			vim.fn.setline(h.lnum, before .. string.rep(" ", pad) .. after)
		end
	end
end

function M.setup()
	-- Define :Align and :align
	vim.api.nvim_create_user_command("Align", align_range, {
		range = true,
		nargs = 1,
		desc = "Align first match of Vim regex in range by inserting spaces before it",
	})
end

return M
