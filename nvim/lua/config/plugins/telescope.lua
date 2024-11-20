require('telescope').setup{
  defaults = {
    mappings = {
      i = {
--        ["<C-j>"] = require('telescope.actions').move_selection_next,
--        ["<C-k>"] = require('telescope.actions').move_selection_previous,
--        ["j"] = require('telescope.actions').move_selection_previous,
--        ["k"] = require('telescope.actions').move_selection_next,
--        ["<Esc>"] = require('telescope.actions').close,
      },
      n = {
        ["j"] = require('telescope.actions').move_selection_previous,
        ["k"] = require('telescope.actions').move_selection_next,
        ["<CR>"] = require('telescope.actions').select_default,
        ["<S-x>"] = require('telescope.actions').select_horizontal,
        ["<S-v>"] = require('telescope.actions').select_vertical,
        ["<S-t>"] = require('telescope.actions').select_tab,
	
	["S-v"] = false,
      },
    },
  },
  pickers = {

  },
  extensions = {

  },
}
