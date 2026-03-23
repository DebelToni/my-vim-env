local transparent_mode = false

return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			require("catppuccin").setup({
				flavour = "mocha",
				transparent_background = transparent_mode,
				custom_highlights = function(colors)
					if not transparent_mode then
						return {}
					end

					return {
						Normal = { bg = "NONE" },
						NormalNC = { bg = "NONE" },
						NormalFloat = { bg = "NONE" },
						FloatBorder = { bg = "NONE" },
						SignColumn = { bg = "NONE" },
						EndOfBuffer = { bg = "NONE" },
						NeoTreeNormal = { bg = "NONE" },
						NeoTreeNormalNC = { bg = "NONE" },
						TelescopeNormal = { bg = "NONE" },
						TelescopeBorder = { bg = "NONE" },
						WinSeparator = { fg = colors.surface1, bg = "NONE" },
					}
				end,
			})

			vim.cmd [[colorscheme catppuccin]]
		end
	},
	{
		"webhooked/kanso.nvim",
		lazy = false,
		priority = 1000,
	}
}
