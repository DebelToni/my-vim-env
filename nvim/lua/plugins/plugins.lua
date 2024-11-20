return {
  {
		  'nvim-lua/plenary.nvim',
		  lazy = false,
  },
  {
    'nvim-telescope/telescope.nvim', 
    version = '0.1.x',
      dependencies = { 'nvim-lua/plenary.nvim' },
      config = function()
        require('telescope').setup{}
      end
  },
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 }, 
  {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
},
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
