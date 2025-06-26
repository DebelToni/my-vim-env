return {
	"tpope/vim-dadbod",
	{"kristijanhusak/vim-dadbod-ui",
		init = function()
			vim.g.db_ui_show_help = 0
		end,
	},
	"kristijanhusak/vim-dadbod-completion"
}
