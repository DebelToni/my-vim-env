local M = {}

local docs_root = vim.fn.expand("~/Documents/ML/SUPER-GIANT-document")
local source_root_name = "SUPER-GIANT"
local hint_win = nil
local hint_buf = nil
local move_augroup = vim.api.nvim_create_augroup("CodeLineHintClose", { clear = true })
local key_ns = vim.api.nvim_create_namespace("CodeLineHintKeys")

local function close_hint()
	if hint_win and vim.api.nvim_win_is_valid(hint_win) then
		vim.api.nvim_win_close(hint_win, true)
	end
	hint_win = nil

	vim.api.nvim_clear_autocmds({ group = move_augroup })
	vim.on_key(nil, key_ns)
end

local function mirror_path(source_path)
	local marker = "/" .. source_root_name .. "/"
	local _, end_at = source_path:find(marker, 1, true)
	if not end_at then
		return nil
	end

	local relative = source_path:sub(end_at + 1)
	return docs_root .. "/" .. relative .. ".md"
end

local function parse_hint_line(line)
	local start_line, end_line, text = line:match("^(%d+)%s*%-%s*(%d+)%s*:%s*(.*)$")
	if start_line then
		return tonumber(start_line), tonumber(end_line), vim.trim(text)
	end

	start_line, text = line:match("^(%d+)%s*:%s*(.*)$")
	if start_line then
		local line_nr = tonumber(start_line)
		return line_nr, line_nr, vim.trim(text)
	end

	return nil, nil, nil
end

local function read_hint(doc_path, line_nr)
	local file = io.open(doc_path, "r")
	if not file then
		return nil
	end

	local best = nil
	for line in file:lines() do
		local start_line, end_line, text = parse_hint_line(line)
		if start_line and start_line <= line_nr and line_nr <= end_line then
			local span = end_line - start_line
			if not best or span < best.span then
				best = { start_line = start_line, end_line = end_line, text = text, span = span }
			end
		end
	end

	file:close()
	if not best then
		return nil
	end
	if best.start_line == best.end_line then
		return string.format("%d: %s", best.start_line, best.text)
	end
	return string.format("%d-%d: %s", best.start_line, best.end_line, best.text)
end

local function wrap_text(text, width)
	if #text <= width then
		return { text }
	end

	local lines = {}
	local current = ""
	for word in text:gmatch("%S+") do
		if current == "" then
			current = word
		elseif #current + 1 + #word <= width then
			current = current .. " " .. word
		else
			table.insert(lines, current)
			current = word
		end
	end
	if current ~= "" then
		table.insert(lines, current)
	end
	return lines
end

local function show_float(text)
	close_hint()

	if not hint_buf or not vim.api.nvim_buf_is_valid(hint_buf) then
		hint_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[hint_buf].buftype = "nofile"
		vim.bo[hint_buf].bufhidden = "hide"
		vim.bo[hint_buf].swapfile = false
	end

	local current_win = vim.api.nvim_get_current_win()
	local win_width = vim.api.nvim_win_get_width(current_win)
	local win_height = vim.api.nvim_win_get_height(current_win)
	local win_pos = vim.api.nvim_win_get_position(current_win)
	local cursor_line = vim.api.nvim_win_get_cursor(current_win)[1]
	local text_pos = vim.fn.screenpos(current_win, cursor_line, 1)
	local left_pad = math.max(0, text_pos.col - win_pos[2] - 1)
	local width = math.max(1, win_width - left_pad)
	local lines = wrap_text(text, width)
	local height = math.min(#lines, 5)
	local max_line_width = 1
	for _, line in ipairs(lines) do
		max_line_width = math.max(max_line_width, #line)
	end
	width = math.min(width, max_line_width)

	vim.api.nvim_buf_set_option(hint_buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(hint_buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(hint_buf, "modifiable", false)

	hint_win = vim.api.nvim_open_win(hint_buf, false, {
		relative = "win",
		win = current_win,
		row = win_height - height,
		col = left_pad,
		width = width,
		height = height,
		style = "minimal",
		border = "none",
		focusable = false,
		zindex = 60,
	})

	vim.wo[hint_win].wrap = false
	vim.api.nvim_set_hl(0, "CodeLineHint", { link = "Comment" })
	vim.api.nvim_win_set_option(hint_win, "winhl", "Normal:CodeLineHint")

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = move_augroup,
		once = true,
		callback = close_hint,
	})

	vim.on_key(function(key)
		if key == "h" or key == "j" or key == "k" or key == "l" then
			vim.schedule(close_hint)
		end
	end, key_ns)

end

function M.show_current_line_hint()
	local source_path = vim.api.nvim_buf_get_name(0)
	local doc_path = mirror_path(source_path)
	if not doc_path then
		show_float("No mirror docs for this file")
		return
	end

	local line_nr = vim.api.nvim_win_get_cursor(0)[1]
	local hint = read_hint(doc_path, line_nr)
	if not hint then
		hint = "No hint for line " .. line_nr
	end

	show_float(hint)
end

function M.setup()
	vim.keymap.set("n", "<leader>k", M.show_current_line_hint, {
		noremap = true,
		silent = true,
		desc = "Show code mirror hint",
	})
end

return M
