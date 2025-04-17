-- return {
-- 	{
-- 		"nvim-telescope/telescope.nvim",
-- 		version = "0.1.x",
-- 		dependencies = {
-- 			"nvim-lua/plenary.nvim",
-- 			"BurntSushi/ripgrep",
-- 		},
-- 		config = function()
-- 			defaults = {
-- 				mappings = {
-- 					i = {
-- 						--        ["<C-j>"] = require('telescope.actions').move_selection_next,
-- 						--        ["<C-k>"] = require('telescope.actions').move_selection_previous,
-- 						--        ["j"] = require('telescope.actions').move_selection_previous,
-- 						--        ["k"] = require('telescope.actions').move_selection_next,
-- 						--        ["<Esc>"] = require('telescope.actions').close,
-- 					},
-- 					n = {
-- 						["j"] = require("telescope.actions").move_selection_previous,
-- 						["k"] = require("telescope.actions").move_selection_next,
-- 						["<CR>"] = require("telescope.actions").select_default,
-- 						["<S-x>"] = require("telescope.actions").select_horizontal,
-- 						["<S-v>"] = require("telescope.actions").select_vertical,
-- 						["<S-t>"] = require("telescope.actions").select_tab,
-- 						["S-v"] = false,
-- 					},
-- 				},
-- 			}
-- 		end,
-- 	},
-- 	{
-- 		"nvim-telescope/telescope-ui-select.nvim",
-- 		config = function()
-- 			require("telescope").setup({
-- 				extensions = {
-- 					["ui-select"] = {
-- 						require("telescope.themes").get_dropdown({}),
-- 					},
-- 				},
-- 			})
-- 			require("telescope").load_extension("ui-select")
-- 		end,
-- 	},
-- }
return {
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.5",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"BurntSushi/ripgrep",
		},
		config = function()
			require("telescope").setup({
				defaults = {
					hidden = true,
					no_ignore = true,
					file_ignore_patterns = {
						"node_modules",
						".ruff_cache",
						".git/",
						".mypy_cache",
					},
					mappings = {
						i = {
							-- Uncomment or add your desired mappings for insert mode:
							-- ["<C-j>"] = require('telescope.actions').move_selection_next,
							-- ["<C-k>"] = require('telescope.actions').move_selection_previous,
						},
						n = {
							["j"] = require("telescope.actions").move_selection_previous,
							["k"] = require("telescope.actions").move_selection_next,
							["<CR>"] = require("telescope.actions").select_default,
							["<S-x>"] = require("telescope.actions").select_horizontal,
							["<S-v>"] = require("telescope.actions").select_vertical,
							["<S-t>"] = require("telescope.actions").select_tab,
							["S-v"] = false,
						},
					},
				},
				pickers = {
					find_files = {
						hidden = true,
						no_ignore = true,
						file_ignore_patterns = {
							"node_modules",
							".ruff_cache",
							".git/",
							".mypy_cache",
						},
					},
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			})
			require("telescope").load_extension("ui-select")
		end,
	},
	{
		"nvim-telescope/telescope-ui-select.nvim",
	},
}

