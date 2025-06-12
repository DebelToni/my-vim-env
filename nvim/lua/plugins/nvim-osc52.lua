return {
  {
    "ojroques/nvim-osc52",
    lazy = true,
    keys = {
      { "<leader><C-c>", function()
          local osc52 = require("osc52")
          osc52.copy_visual()
        end, mode = { "v" }, desc = "Copy via OSC52" },
    },
    config = function()
      require("osc52").setup({
        -- optional settings can go here
        max_length = 0,  -- no limit on size
      })
      -- integrate with system clipboard registers
      local copy = function(lines)
        require("osc52").copy(table.concat(lines, "\n"))
      end
      vim.g.clipboard = {
        name = "osc52",
        copy = { ["+"] = copy, ["*"] = copy },
        paste = { ["+"] = copy, ["*"] = copy },
      }
    end,
  },
}

