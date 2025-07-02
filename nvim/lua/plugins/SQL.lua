return {
	"tpope/vim-dadbod",
	{
		"kristijanhusak/vim-dadbod-ui",
		init = function()
			vim.g.db_ui_show_help = 0
			vim.g.db_ui_save_location = '~/Documents/rst/sql'
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_force_echo_notifications = 1
			vim.g.db_ui_execute_on_save = 0	

		end,
	},
	-- {
	-- 	"kristijanhusak/vim-dadbod-ui",
	-- 	init = function()
	-- 		vim.g.db_ui_show_help = 0
	-- 		vim.g.db_ui_save_location = '~/Documents/rst/sql'
	-- 		vim.g.db_ui_use_nerd_fonts = 1
	--
	-- 		-- map <Space><Enter> for SQL execution
	-- 		vim.api.nvim_buf_set_keymap(
	-- 			0, "n", "<leader>a",
	-- 			"vip<Plug>(DBUI_ExecuteQuery)",
	-- 			{ silent = true, noremap = false, desc = "Execute SQL under cursor" }
	-- 		)
	-- 		vim.api.nvim_buf_set_keymap(
	-- 			0, "v", "<leader><CR>",
	-- 			"<Plug>(DBUI_ExecuteQuery)",
	-- 			{ silent = true, noremap = false, desc = "Execute selected SQL" }
	-- 		)
	-- 	end,
	-- },
	"kristijanhusak/vim-dadbod-completion"
}
