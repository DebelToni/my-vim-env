-- return {
--   {
--     "CopilotC-Nvim/CopilotChat.nvim",
--     dependencies = {
--       { "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
--       { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
--     },
--     build = "make tiktoken", -- Only on MacOS or Linux
--     opts = {
--       -- See Configuration section for options
--     },
--     keys = {
--       { "<leader>cp", ":CopilotChatOpen<CR>", desc = "Open CopilotChat" },
--       { "<leader>cm", ":CopilotChatModels<CR>", desc = "Switch Copilot Model" },
--     },
--   },
-- }
return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = {
      { "github/copilot.vim" },      -- or zbirenbaum/copilot.lua
      { "nvim-lua/plenary.nvim" },   -- for curl, log and async functions
    },
    build = "make tiktoken",         -- Only on MacOS or Linux
    opts = {
      mappings = {
        reset = {
          normal = false,
          insert = false,
        },
      },
      -- …you can still keep other CopilotChat options here…
    },
    keys = {
      { "<leader>cp", ":CopilotChatOpen<CR>",  desc = "Open CopilotChat" },
      { "<leader>cm", ":CopilotChatModels<CR>", desc = "Switch Copilot Model" },
    },
  },
}

