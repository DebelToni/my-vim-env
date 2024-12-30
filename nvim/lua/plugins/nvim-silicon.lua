return {
  {
  "michaelrommel/nvim-silicon",
  --dependencies = { 'nvim-lua/plenary.nvim' },
  lazy = true,
  cmd = "Silicon",
  config = function()
    require('nvim-silicon').setup({
		wslclipboard = 'always',
		wslclipboardcopy = 'keep',
		--background = nil,
		background = "#00FFFF",
		pad_horiz = 40,
		pad_vert = 40,
		debug = false,
	})
  end,
}

}
