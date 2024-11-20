vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

--Todo: make file for require
require("config.lazy")
require("config.plugins.telescope")
require("config.plugins.which_key")
require("config.myscripts.code_conceal")
require("config.myscripts.code_hide")

require("config.keybinds")

--Todo: make file for customisaion
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4

--Todo: find a better colorscheme
require("catppuccin").setup({ flavour = "mocha", })
vim.cmd [[colorscheme catppuccin]]

