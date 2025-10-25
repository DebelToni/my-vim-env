vim.g.mapleader = " "
-- vim.g.maplocalleader = "\\"

vim.opt.wrap = true
vim.opt.relativenumber = true
vim.opt.number = true

--Todo: make file for require
require("config.lazy")
require("config.myscripts.code_conceal")
require("config.myscripts.code_hide")
require("config.myscripts.removecomments")
require("config.plugins.which-key")
-- require("config.dynamic_yank").start()
require("config.myscripts.switch-to-english")
require("config.myscripts.floating_terminal")
-- require("config.myscripts.move_upORdown_better_in_markdown")
require("config.myscripts.narrow_buffer").setup()
-- require("config.myscripts.prompt_search").setup { model = "llama3.2:1b",       endpoint = "http://localhost:11434/api/generate", max_context_lines = 400,  }
require("LSP_config")
require("mini.bufremove").setup()
require("mini.pick").setup()

require("config.keybinds")
--Todo: make file for customisaion
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.wrap = true

local tabs = 4

vim.opt.tabstop = tabs
vim.o.tabstop = tabs

vim.o.tabstop = tabs     -- A TAB character looks like tabs spaces
-- vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = tabs -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = tabs  -- Number of spaces inserted when indenting




-- ~/.config/nvim/init.lua

-- 1) Load built-in defaults (cursor restore, shada, etc.)
vim.cmd('runtime defaults.vim')

-- 2) Optional: center the cursor on restore
vim.api.nvim_create_autocmd('BufReadPost', {
	pattern = '*',
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		if mark[1] > 1 and mark[1] <= vim.api.nvim_buf_line_count(0) then
			vim.cmd('normal! g`"')
			vim.cmd('normal! zz')
		end
	end,
})

-- 3) Remember full “view” (cursor + scroll + folds + more)
--    on window leave…
vim.api.nvim_create_autocmd('BufWinLeave', {
	pattern = '*',
	command = 'silent! mkview'
})

--    …and restore it on window enter
vim.api.nvim_create_autocmd('BufWinEnter', {
	pattern = '*',
	command = 'silent! loadview'
})
