-- return {
-- 	{
-- 		"michaelrommel/nvim-silicon",
-- 		--dependencies = { 'nvim-lua/plenary.nvim' },
-- 		lazy = false, -- if wsl works
-- 		-- enabled = false,
-- 		cmd = "Silicon",
-- 		config = function()
-- 			require("nvim-silicon").setup({
-- 				wslclipboard = "always",
-- 				wslclipboardcopy = "keep",
-- 				--background = nil,
-- 				background = "#00FFFF",
-- 				pad_horiz = 40,
-- 				pad_vert = 40,
-- 				debug = false,
-- 			})
-- 		end,
-- 	},
-- }
return {
	{
		"michaelrommel/nvim-silicon",
		-- dependencies = { 'nvim-lua/plenary.nvim' },
		lazy = false, -- if WSL works
		cmd = "Silicon",
		config = function()
			require("nvim-silicon").setup({
				disable_defaults = true, -- disable silicon's built-in defaults
				debug = false,
				-- font = "VictorMono NF=34;Noto Emoji", -- adjust font as desired
				-- theme = "catppuccin-mocha", -- custom theme label
				background = "#1E1E2E", -- Catppuccin Mocha base color
				pad_horiz = 100,
				pad_vert = 80,
				no_round_corner = false,
				no_window_controls = false,
				no_line_number = false,
				line_offset = 1,
				line_pad = 0,
				tab_width = 4,
				language = function()
					return vim.bo.filetype
				end,
				shadow_blur_radius = 16,
				shadow_offset_x = 8,
				shadow_offset_y = 8,
				shadow_color = "#11111B", -- a dark accent/shadow color
				gobble = true,
				num_separator = nil,
				to_clipboard = false,
				window_title = nil,
				-- Using WSL clipboard options as needed
				-- wslclipboard = "always",
				-- wslclipboardcopy = "keep",
				-- Specify silicon command with custom config file for Catppuccin Mocha
				-- command = "silicon --theme ~/.config/silicon/catppuccin-mocha.tmTheme",
				output = function()
					return "./" .. os.date("!%Y-%m-%dT%H-%M-%SZ") .. "_code.png"
				end,
			})
		end,
	},
}
