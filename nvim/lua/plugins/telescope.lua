-- Telescope (single file config)
-- NOTE: ripgrep is an external binary (recommended):
--   macOS: brew install ripgrep

return {
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",

			-- Keep all Telescope-related plugins in one place:
			"nvim-telescope/telescope-ui-select.nvim",

			-- If you *really* want this in lazy, you can keep it,
			-- but it's not required and ripgrep is usually installed via your package manager.
			-- "BurntSushi/ripgrep",
		},
		config = function()
			-- =========================================================================
			-- Requires
			-- =========================================================================
			local telescope = require("telescope")
			local builtin = require("telescope.builtin")
			local actions = require("telescope.actions")
			local action_state = require("telescope.actions.state")

			-- =========================================================================
			-- Global keymaps (outside Telescope UI)
			-- =========================================================================
			vim.keymap.set({ "n" }, "<leader>si", builtin.grep_string, { desc = "Telescope live string" })
			vim.keymap.set({ "n" }, "<leader>sr", builtin.lsp_references, { desc = "Telescope LSP references" })

			-- =========================================================================
			-- Helper actions: switch pickers while keeping the current prompt text
			-- =========================================================================
			local function get_prompt(prompt_bufnr)
				local picker = action_state.get_current_picker(prompt_bufnr)
				return picker and picker:_get_prompt() or ""
			end

			local function switch_to_live_grep(prompt_bufnr)
				local text = get_prompt(prompt_bufnr)
				actions.close(prompt_bufnr)
				builtin.live_grep({ default_text = text })
			end

			local function switch_to_find_files(prompt_bufnr)
				local text = get_prompt(prompt_bufnr)
				actions.close(prompt_bufnr)
				builtin.find_files({ default_text = text })
			end

			-- =========================================================================
			-- Telescope setup
			-- =========================================================================
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

					layout_strategy = "vertical",
					layout_config = {
						vertical = {
							width = 0.999,
							height = 0.999,
							preview_height = 0.50,
							mirror = true, -- preview on top
							prompt_position = "bottom",
							preview_cutoff = 0,
						},
					},

					mappings = {
						-- Insert mode mappings *inside Telescope*
						i = {
							-- IMPORTANT: <C-g> can incur timeoutlen delay unless nowait=true
							["<C-g>"] = { switch_to_live_grep, type = "action", opts = { nowait = true, silent = true } },
							["<C-f>"] = { switch_to_find_files, type = "action", opts = { nowait = true, silent = true } },
						},

						-- Normal mode mappings *inside Telescope*
						n = {
							["j"] = actions.move_selection_previous,
							["k"] = actions.move_selection_next,

							["<CR>"] = actions.select_default,
							["<S-x>"] = actions.select_horizontal,
							["<S-v>"] = actions.select_vertical,
							["<S-t>"] = actions.select_tab,

							-- your existing disable
							["S-v"] = false,

							-- Switch picker, keep the text you've typed
							["<C-g>"] = { switch_to_live_grep, type = "action", opts = { nowait = true, silent = true } },
							["<C-f>"] = { switch_to_find_files, type = "action", opts = { nowait = true, silent = true } },
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

					live_grep = {},
					grep_string = {},
					lsp_references = {},
				},

				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			})

			-- =========================================================================
			-- Extensions
			-- =========================================================================
			pcall(telescope.load_extension, "ui-select")
		end,
	},
}
