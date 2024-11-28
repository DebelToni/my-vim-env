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
	})

	end
}

}
