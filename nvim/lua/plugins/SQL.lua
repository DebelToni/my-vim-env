return {
	"tpope/vim-dadbod",
	{"kristijanhusak/vim-dadbod-ui",
		init = function()
			vim.g.db_ui_show_help = 0
			vim.g.db_ui_save_location = '~/Documents/rst/sql'
		end,
	},
	"kristijanhusak/vim-dadbod-completion"
}
