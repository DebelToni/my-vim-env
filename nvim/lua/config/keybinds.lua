local set_keymap = function(mode, lhs, rhs, opts)
	local options = { noremap = true, silent = true }
	if opts then
		options = vim.tbl_extend('force', options, opts)
	end
	vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- set_keymap('n', 'j', 'k', { desc = "Move up" })
-- set_keymap('v', 'j', 'k', { desc = "Move up in visual mode" })
--
-- set_keymap('n', 'k', 'j', { desc = "Move down" })
-- set_keymap('v', 'k', 'j', { desc = "Move down in visual mode" })

-- set_keymap('n', ';', ':', { desc = "Enter command-line with ;" })
-- set_keymap('v', ';', ':', { desc = "Enter command-line with ; in visual mode" })
-- set_keymap('n', ':', ';', { desc = "Search with ;" })
-- set_keymap('v', ':', ';', { desc = "Search with ; in visual mode" })

vim.keymap.set('n', '<Esc>', ':nohlsearch<CR>:wa<CR>', { silent = true, noremap = true })

local modes = { 'n', 'i', 'v', 'x', 's', 'o' } -- Normal, Insert, Visual, Select, Operator-pending modes
-- for _, mode in ipairs(modes) do
-- 	set_keymap(mode, '<Up>', '<NOP>', { noremap = true, silent = true, desc = "Disable Up Arrow" })
-- 	set_keymap(mode, '<Down>', '<NOP>', { noremap = true, silent = true, desc = "Disable Down Arrow" })
-- 	set_keymap(mode, '<Left>', '<NOP>', { noremap = true, silent = true, desc = "Disable Left Arrow" })
-- 	set_keymap(mode, '<Right>', '<NOP>', { noremap = true, silent = true, desc = "Disable Right Arrow" })
-- end

-- Telescope
set_keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
set_keymap("n", "<leader>fa", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
set_keymap("n", "<leader>fs", "<cmd>Telescope live_grep<cr>", { desc = "Grep text in files" })
set_keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "List buffers" })
set_keymap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })
set_keymap("n", "<leader>fc", "<cmd>Telescope commands<cr>", { desc = "List commands" })

--Tmux
set_keymap("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "Nav left" })
set_keymap("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>", { desc = "Nav up" })
-- set_keymap("n", "<C-j>", "<cmd>TmuxNavigateUp<cr>", {desc = "Nav up"})
set_keymap("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>", { desc = "Nav down" })
-- set_keymap("n", "<C-k>", "<cmd>TmuxNavigateDown<cr>", {desc = "Nav down"})
set_keymap("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>", { desc = "Nav right" })

--vim.api.nvim_set_keymap('v', '<leader>s', [[:lua require('silicon').visualise_api({})<CR>]], { noremap = true, silent = true })
--vim.keymap.set('v', '<Leader>s',  function() silicon.visualise_api() end )
--vim.api.nvim_set_keymap('v', '<leader>s', ':Silicon<CR>', { noremap = true, silent = true })

--vim.api.nvim_set_keymap('n', '<F5>', ':lua ToggleHideTaggedLines()<CR>', { noremap = true, silent = true })

-- vim.api.nvim_set_keymap('n', '<A-j>', ':m-2<CR>==', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', '<A-k>', ':m+1<CR>==', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('v', '<A-k>', ":m'>+<CR>gv=gv", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('v', '<A-j>', ":m'<-2<CR>gv=gv", { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<A-k>', ':m-2<CR>==', { noremap = true, silent = true, desc = "Move line up" })
vim.api.nvim_set_keymap('n', '<A-j>', ':m+1<CR>==', { noremap = true, silent = true, desc = "Move line down" })
vim.api.nvim_set_keymap('v', '<A-j>', ":m'>+<CR>gv=gv", { noremap = true, silent = true, desc = "Move line down" })
vim.api.nvim_set_keymap('v', '<A-k>', ":m'<-2<CR>gv=gv", { noremap = true, silent = true, desc = "Move line up" })

vim.api.nvim_set_keymap('n', '<leader>b', ':b#<CR>', { noremap = true, desc = "Switch to previous buffer" })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { noremap = true, silent = true, desc = "Open diagnostics" })

-- set_keymap('n', 'V', '<C-v>', { desc = "Visual block mode" })

vim.keymap.set('n', '<M-k>', function()
	vim.cmd('resize +' .. (vim.v.count1 == 1 and 5 or vim.v.count1))
end, { desc = 'Resize window ↑ (count-aware)', silent = true })

vim.keymap.set('n', '<M-j>', function()
	vim.cmd('resize -' .. (vim.v.count1 == 1 and 5 or vim.v.count1))
end, { desc = 'Resize window ↓ (count-aware)', silent = true })

vim.keymap.set('n', '<M-h>', function()
	vim.cmd('vertical resize -' .. (vim.v.count1 == 1 and 5 or vim.v.count1))
end, { desc = 'Resize window ← (count-aware)', silent = true })

vim.keymap.set('n', '<M-l>', function()
	vim.cmd('vertical resize +' .. (vim.v.count1 == 1 and 5 or vim.v.count1))
end, { desc = 'Resize window → (count-aware)', silent = true })

-- vim.api.nvim_set_keymap('n', '<leader>z', ':ZenMode<CR>', { noremap = true, silent = true, desc = "Toggle Zen Mode" })

vim.api.nvim_set_keymap('n', '<leader>dm', '<cmd>NoiceDismiss<CR>',
	{ noremap = true, silent = true, desc = "Dismiss noice messages" })


vim.api.nvim_set_keymap('t', '<Esc>', '<C-\\><C-n>', { noremap = true, silent = true, desc = "Exit terminal mode" })

vim.api.nvim_set_keymap('n', '<leader>o', ':Oil<CR>', { noremap = true, silent = true, desc = "Open oil file explorer" })

vim.api.nvim_set_keymap('n', '<leader>l', ':Pick buffers<CR>', { noremap = true, silent = true, desc = "Pick buffer" })
vim.keymap.set('n', '<leader>dl', require("mini.bufremove").delete)

for i = 1, 8 do
	vim.api.nvim_set_keymap("n", "<Leader>" .. i, "<Cmd>tabnext " .. i .. "<CR>",
		{ noremap = true, silent = true, desc = "Go to tab " .. i })
end

vim.api.nvim_set_keymap("n", "<leader>t", "<cmd>tabnew<CR>", { noremap = true, silent = true, desc = "Open new tab" })
vim.api.nvim_set_keymap("n", "<leader>q", ":q<CR>", { noremap = true, silent = true, desc = "Open new tab" })
vim.api.nvim_set_keymap("v", "<leader>n", ":norm ", { noremap = true, silent = true, desc = "norm" })
vim.api.nvim_set_keymap("n", "<leader>n", ":norm ", { noremap = true, silent = true, desc = "norm" })

vim.api.nvim_set_keymap("n", "<leader>gi", ":Gitsigns ", { noremap = true, silent = true, desc = "norm" })
