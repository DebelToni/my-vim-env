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
local tabs = 2
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.tabstop = tabs
vim.o.tabstop = tabs

vim.o.tabstop = tabs -- A TAB character looks like 4 spaces
-- vim.o.expandtab = true -- Pressing the TAB key will insert spaces instead of a TAB character
vim.o.softtabstop = tabs -- Number of spaces inserted instead of a TAB character
vim.o.shiftwidth = tabs -- Number of spaces inserted when indenting
vim.o.relativenumber = true

-- godot
--
-- require("lspconfig")["gdscript"].setup({
--   name = "godot",
--   cmd = vim.lsp.rpc.connect("127.0.0.1", "6005"),
-- })
--
--
-- local dap = require("dap")
-- dap.adapters.godot = {
--   type = "server",
--   host = "127.0.0.1",
--   port = 6006,
-- }
--
-- dap.configurations.gdscript = {
--   {
--     type = "godot",
--     request = "launch",
--     name = "Launch scene",
--     project = "${workspaceFolder}",
--     launch_scene = true,
--   },
-- }
--
