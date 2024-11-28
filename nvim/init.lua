vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

--Todo: make file for require
require("config.lazy")
require("config.myscripts.code_conceal")
require("config.myscripts.code_hide")
require("config.plugins.which-key")
require("config.keybinds")

--Todo: make file for customisaion
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4

