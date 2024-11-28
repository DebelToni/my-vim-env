return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    {
      "<leader>?",
      function()
		show({ global = false })
        --require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
		
    },
  }
}
