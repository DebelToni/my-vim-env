-- return {
-- 	"folke/zen-mode.nvim",
-- 	config = function()
-- 		require("zen-mode").setup({
-- 			window = {
-- 				width = 0.95,
-- 				-- width = 1,
-- 				height = 0.95,
-- 			},
-- 			plugins = {
-- 				twilight = { enabled = true }, -- enable to start Twilight when zen mode opens
-- 				gitsigns = { enabled = false }, -- disables git signs
-- 				tmux = { enabled = true }, -- disables the tmux statusline
-- 				todo = { enabled = false },
-- 			},
-- 			on_open = function(win) end,
-- 			on_close = function() end,
-- 		})
-- 	end,
-- }
return {
	"folke/zen-mode.nvim",
	config = function()
		local zen_mode = require("zen-mode")

		-- that keeps it in tmux
		vim.keymap.set("n", "<leader>zt", function()
			zen_mode.setup({
				window = {
					width = 0.95,
					height = 0.95,
				},
				plugins = {
					twilight = { enabled = true },
					gitsigns = { enabled = false },
					todo = { enabled = false },
					tmux = { enabled = false },
				},
				on_open = function()
					vim.cmd("Copilot disable")
				end,
				on_close = function()
					vim.cmd("Copilot enable")
				end,
			})
			zen_mode.toggle()
		end, { desc = "ZenMode with Tmux disabled" })

		-- that is ultimate zen mode
		vim.keymap.set("n", "<leader>zz", function()
			zen_mode.setup({
				window = {
					width = 0.95,
					height = 0.95,
				},
				plugins = {
					twilight = { enabled = true },
					gitsigns = { enabled = false },
					todo = { enabled = false },
					tmux = { enabled = true },
				},
				on_open = function()
					vim.cmd("Copilot disable")
				end,
				on_close = function()
					vim.cmd("Copilot enable")
				end,
			})
			zen_mode.toggle()
		end, { desc = "ZenMode with Tmux enabled" })
	end,
}
