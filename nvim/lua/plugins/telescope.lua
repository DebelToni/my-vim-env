-- telescope.lua (fixed full-buffer + top preview for grep)
return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"BurntSushi/ripgrep",
		},
		config = function()
			local telescope = require("telescope")
			local builtin = require("telescope.builtin")

			vim.keymap.set({ "n" }, "<leader>si", builtin.grep_string, { desc = "Telescope live string" })
			vim.keymap.set({ "n" }, "<leader>sr", builtin.lsp_references, { desc = "Telescope LSP references" })

			telescope.setup({
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
						file_ignore_patterns = {
							"node_modules",
							".ruff_cache",
							".git/",
							".mypy_cache",
							"venv",
							"__pycache__",
						},
					},

					-- Full-buffer grep with preview on TOP (50%) and results+prompt on bottom (50%)
					live_grep = {
						layout_strategy = "vertical",
						layout_config = {
							-- IMPORTANT: use < 1.0 so Telescope treats it as a fraction, not absolute cells
							vertical = {
								width = 0.999,
								height = 0.999,
								preview_height = 0.50, -- top pane height
								mirror = true, -- put preview ABOVE results
								prompt_position = "bottom",
								preview_cutoff = 0, -- never hide preview
							},
						},
					},
					grep_string = {
						layout_strategy = "vertical",
						layout_config = {
							vertical = {
								width = 0.999,
								height = 0.999,
								preview_height = 0.50,
								mirror = true,
								prompt_position = "bottom",
								preview_cutoff = 0,
							},
						},
					},
					lsp_references = {
						layout_strategy = "vertical",
						layout_config = {
							vertical = {
								width = 0.999,
								height = 0.999,
								preview_height = 0.50,
								mirror = true,
								prompt_position = "bottom",
								preview_cutoff = 0,
							},
						},
					},
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			})

			telescope.load_extension("ui-select")
		end,
	},
	{
		"nvim-telescope/telescope-ui-select.nvim",
	},
}
