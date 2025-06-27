return {
	"tpope/vim-dadbod",
	{
		"kristijanhusak/vim-dadbod-ui",
		init = function()
			vim.g.db_ui_show_help = 0
			vim.g.db_ui_save_location = '~/Documents/rst/sql'
			vim.g.db_ui_use_nerd_fonts = 1
		end,
	},
	"kristijanhusak/vim-dadbod-completion"
}
