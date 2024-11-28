return {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      -- "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
      --"3rd/image.nvim",
	  },
	  config = function()
    require("neo-tree").setup({
    })

    vim.keymap.set("n", "<leader>t", ":Neotree toggle<CR>", { desc = "Toggle Neo-tree" })
    vim.keymap.set("n", "<leader>n", function()
      local neo_tree_open = vim.fn.bufname() == "Neo-tree"
      if neo_tree_open then
        vim.cmd("wincmd p")
      else
        vim.cmd("Neotree focus")
      end
    end, { desc = "Toggle focus/unfocus Neo-tree" })
    vim.keymap.set("n", "<leader>b", "<C-w>p", { desc = "Go back to previous window" })
	end,
}
