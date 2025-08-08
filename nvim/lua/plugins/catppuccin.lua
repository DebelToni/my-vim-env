return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			vim.cmd [[colorscheme catppuccin]]
		end
	},
	{
		"webhooked/kanso.nvim",
		lazy = false,
		priority = 1000,
	}
}
