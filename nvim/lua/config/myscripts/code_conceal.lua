--Custom script to make $ tagged code lines apear as ...
local conceal_ns = vim.api.nvim_create_namespace("toggle_hide_dollar_lines")

local hide_dollar_enabled = false

local function ToggleHideDollarLines()
  if not hide_dollar_enabled then
    vim.cmd [[
      syntax match HideDollarLines /^.*\$$/ conceal cchar=⋯
      highlight link HideDollarLines Conceal
    ]]
    vim.wo.conceallevel = 2
    hide_dollar_enabled = true
  else
    vim.cmd [[
      syntax clear HideDollarLines
      highlight clear HideDollarLines
    ]]
    vim.wo.conceallevel = 0
    hide_dollar_enabled = false
  end
end

vim.keymap.set('n', '<leader>c', ToggleHideDollarLines, { noremap = true, silent = true })
