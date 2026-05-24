return {
	"3rd/image.nvim",
	build = false, -- so that it doesn't build the rock https://github.com/3rd/image.nvim/issues/91#issuecomment-2453430239
	opts = {
		processor = "magick_cli",
		editor_only_render_when_focused = true,
		tmux_show_only_in_active_window = true,
	},
	config = function(_, opts)
		require("image").setup(opts)

		-- Extra safety for Ghostty/Kitty graphics: delete all placements when Neovim exits.
		-- This prevents stale images if image.nvim misses its normal cleanup path.
		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = vim.api.nvim_create_augroup("ghostty_image_cleanup", { clear = true }),
			callback = function()
				pcall(require("image").clear)
				io.stdout:write("\27_Ga=d,d=A\27\\")
				io.stdout:flush()
			end,
		})
	end,
}
