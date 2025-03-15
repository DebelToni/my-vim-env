vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

--Todo: make file for require
require("config.lazy")
require("config.myscripts.code_conceal")
require("config.myscripts.code_hide")
require("config.plugins.which-key")
require("config.keybinds")
-- require("config.dynamic_yank").start()
require("config.myscripts.switch-to-english")
require("config.myscripts.floating_terminal")
require("config.myscripts.move_upORdown_better_in_markdown")


--Todo: make file for customisaion
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.o.tabstop = 4

vim.o.tabstop = 4 -- A TAB character looks like 4 spaces
vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = 4 -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = 4 -- Number of spaces inserted when indenting
vim.o.relativenumber = true
