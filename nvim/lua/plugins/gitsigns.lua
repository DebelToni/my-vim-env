-- lua/plugins/gitsigns.lua
-- Lazy.nvim plugin spec for lewis6991/gitsigns.nvim
-- Returns a table you can import from your lazy setup.

return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = { "nvim-lua/plenary.nvim" },

	opts = {
		-- Ensure the sign column is always shown so signs don't shift text
		-- (If you set this elsewhere, feel free to remove this.)
		-- Note: this is a global option; we also set it in config below.
		signs = {
			add          = { text = "+" },
			change       = { text = "│" }, -- or "~" if you want change to look “wavy” too
			delete       = { text = "_" }, -- bottom delete marker
			topdelete    = { text = "‾" }, -- top delete marker (different from "_" so it actually reads as “top”)
			changedelete = { text = "~" }, -- change+delete
			untracked    = { text = "?" }, -- or "┆"
		},


		-- Show signs in new (untracked) files as well
		attach_to_untracked = true,

		-- Optional: enable/disable as you like
		signcolumn = true,
		numhl = false,
		linehl = false,
		word_diff = false,

		-- How often to check for changes (ms)
		watch_gitdir = { interval = 1000, follow_files = true },

		-- Statusline helper (optional)
		status_formatter = nil,

		-- Hunk preview window appearance
		preview_config = {
			border = "single",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},

		-- Current line blame (off by default; toggle with keymap)
		current_line_blame = false,
		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- "eol" | "overlay" | "right_align"
			delay = 300,
			ignore_whitespace = false,
			virt_text_priority = 100,
		},
	},

	config = function(_, opts)
		-- Make sure signcolumn is enabled globally (recommended for git signs)
		vim.opt.signcolumn = "yes"

		require("gitsigns").setup(opts)
	end,
}
