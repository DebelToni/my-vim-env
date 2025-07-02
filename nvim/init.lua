vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

--Todo: make file for require
require("config.lazy")
require("config.myscripts.code_conceal")
require("config.myscripts.code_hide")
require("config.myscripts.removecomments")
require("config.plugins.which-key")
require("config.keybinds")
-- require("config.dynamic_yank").start()
require("config.myscripts.switch-to-english")
require("config.myscripts.floating_terminal")
require("config.myscripts.move_upORdown_better_in_markdown")
-- require("config.myscripts.prompt_search").setup { model = "llama3.2:1b",       endpoint = "http://localhost:11434/api/generate", max_context_lines = 400,  }

--Todo: make file for customisaion
vim.opt.number = true
vim.opt.relativenumber = true

local tabs = 4

vim.opt.tabstop = tabs
vim.o.tabstop = tabs

vim.o.tabstop = tabs -- A TAB character looks like tabs spaces
-- vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = tabs -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = tabs -- Number of spaces inserted when indenting
