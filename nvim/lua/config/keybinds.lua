local set_keymap = function(mode, lhs, rhs, opts)
    local options = { noremap = true, silent = true }
    if opts then
      options = vim.tbl_extend('force', options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
  end
  
set_keymap('n', 'j', 'k', { desc = "Move up" })
set_keymap('v', 'j', 'k', { desc = "Move up in visual mode" })

set_keymap('n', 'k', 'j', { desc = "Move down" })
set_keymap('v', 'k', 'j', { desc = "Move down in visual mode" })

set_keymap('n', ';', ':', {desc = "Enter command-line with ;"})


local modes = { 'n', 'i', 'v', 'x', 's', 'o' } -- Normal, Insert, Visual, Select, Operator-pending modes
for _, mode in ipairs(modes) do
	set_keymap(mode, '<Up>', '<NOP>', { noremap = true, silent = true, desc = "Disable Up Arrow" })
	set_keymap(mode, '<Down>', '<NOP>', { noremap = true, silent = true, desc = "Disable Down Arrow" })
	set_keymap(mode, '<Left>', '<NOP>', { noremap = true, silent = true, desc = "Disable Left Arrow" })
	set_keymap(mode, '<Right>', '<NOP>', { noremap = true, silent = true, desc = "Disable Right Arrow" })
end

-- Telescope
set_keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", {desc = "Find files"})
set_keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", {desc = "Grep text in files"})
set_keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>", {desc = "List buffers"})
set_keymap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", {desc = "Help tags"})

--Tmux
set_keymap("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", {desc = "Nav left"})
set_keymap("n", "<C-j>", "<cmd>TmuxNavigateUp<cr>", {desc = "Nav up"})
set_keymap("n", "<C-k>", "<cmd>TmuxNavigateDown<cr>", {desc = "Nav down"})
set_keymap("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", {desc = "Nav right"})

--vim.api.nvim_set_keymap('v', '<leader>s', [[:lua require('silicon').visualise_api({})<CR>]], { noremap = true, silent = true })
--vim.keymap.set('v', '<Leader>s',  function() silicon.visualise_api() end )
--vim.api.nvim_set_keymap('v', '<leader>s', ':Silicon<CR>', { noremap = true, silent = true })

--vim.api.nvim_set_keymap('n', '<F5>', ':lua ToggleHideTaggedLines()<CR>', { noremap = true, silent = true })

