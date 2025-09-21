return {
  "ojroques/nvim-osc52",
  event = "TextYankPost",               -- load the plugin the first time you yank
  keys = {                              -- also load when pressing these keys
    {
      "<leader>y",
      function() require("osc52").copy_visual() end,
      mode = "v",
      desc = "OSC52: copy selection",
    },
  },
  opts = {
    max_length = 0,
    silent = true,
    trim = false,
  },
  config = function(_, opts)
    require("osc52").setup(opts)

    -- Copy every yank to OSC52 (only when using the unnamed register)
    vim.api.nvim_create_autocmd("TextYankPost", {
      callback = function()
        if vim.v.event.operator == "y" and vim.v.event.regname == "" then
          require("osc52").copy_register('"')
        end
      end,
    })
  end,
}

