-- return {
-- 	"folke/snacks.nvim",
-- 	priority = 1000,
-- 	lazy = false,
-- 	opts = {
-- 		image = {
-- 			enabled = true,
-- 			doc = {
-- 				enabled = true,
-- 				inline = true,
-- 				float = true,
-- 			},
-- 			math = {
-- 				enabled = true,
-- 			},
-- 		},
-- 	},
-- }
return {
	'MeanderingProgrammer/render-markdown.nvim',
	dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
	-- -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
	-- -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
	---@module 'render-markdown'
	---@type render.md.UserConfig
	opts = {},
}
