local function is_md()
	local filename = vim.fn.expand("%:t")
	if
		filename[string.len(filename) - 1] == "d"
		and filename[string.len(filename) - 2] == "m"
		and filename[string.len(filename) - 3] == "."
	then
		return 1
	else
		return 0
	end
end

local test_functionality = function()
	if not is_md() then
		return
	end
	local current_line = vim.api.nvim_get_current_line()
	local current_win_width = vim.api.nvim_win_get_width(0) - 4
	local line_to_win_ratio = string.len(current_line) / current_win_width
	local cursor_pos = vim.api.nvim_win_get_cursor(0)[2]
	local cursor_y = vim.api.nvim_win_get_cursor(0)[1]
	local setted = false
	local settedj = false

	if line_to_win_ratio > 1 then
		-- print("big")
		-- if cursor_pos < string.len(current_line) - string.len(current_line) % current_win_width then
		if cursor_pos + current_win_width < string.len(current_line) then
			settedj = true
			vim.api.nvim_set_keymap("n", "j", "" .. current_win_width .. "l", {})
		else
			-- vim.keymap.del("n", "j")
			-- vim.api.nvim_del_keymap("n","j")
			vim.api.nvim_set_keymap("n", "j", "j", {})
		end

		if cursor_pos - current_win_width >= 0 then
			setted = true
			vim.api.nvim_set_keymap("n", "k", "" .. current_win_width .. "h", {})
		else
			-- vim.keymap.del("n", "k")
			-- vim.api.nvim_del_keymap("n","k")
			vim.api.nvim_set_keymap("n", "k", "k", {})
		end
	else
		-- vim.keymap.del("n", "j")
		-- vim.keymap.del("n", "k")
		vim.api.nvim_set_keymap("n", "k", "k", {})
		vim.api.nvim_set_keymap("n", "j", "j", {})
	end

	-- if cursor_y > 1 and string.len(current_line)>current_win_width then
	if cursor_y > 1 then
		local line_above = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), cursor_y - 2, cursor_y - 1, 0)[1]
		-- print(string.len(line_above) > current_win_width)
		if string.len(line_above) > current_win_width then
			vim.api.nvim_set_keymap(
				"n",
				"k",
				-- "k" .. "$" .. string.len(line_above) % current_win_width .. "h",
				"k"
					.. "$"
					.. string.len(line_above) % current_win_width
					.. "h"
					.. cursor_pos + 1
					.. "l",
				{}
			)
		else
			if not setted then
				vim.api.nvim_set_keymap("n", "k", "k", {})
			end
		end
	end
	if true then
		if
			string.len(current_line) > current_win_width
			and cursor_pos + current_win_width > string.len(current_line)
		then
			if cursor_pos % current_win_width == 0 then
				vim.api.nvim_set_keymap("n", "j", "j" .. "0", {})
			else
				vim.api.nvim_set_keymap("n", "j", "j" .. "0" .. cursor_pos % current_win_width .. "l", {})
			end
			-- print(cursor_pos % current_win_width)
		else
			if not settedj then
				vim.api.nvim_set_keymap("n", "j", "j", {})
			end
		end
	end
end

vim.api.nvim_create_user_command("Testfunctionalit", test_functionality, {})

vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved" }, {
	pattern = "*.md",
	callback = function()
		test_functionality()
	end,
})
