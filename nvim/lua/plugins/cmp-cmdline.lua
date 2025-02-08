--   {
--     "hrsh7th/nvim-cmp",
--     dependencies = {
--       "hrsh7th/cmp-nvim-lsp",
--       "hrsh7th/cmp-buffer",
--       "hrsh7th/cmp-path",
--       "hrsh7th/cmp-cmdline",
--     },
--     config = function()
--       local cmp = require("cmp")
--
--       -- Basic insert-mode completion configuration.
--       cmp.setup({
--         snippet = {
--           -- If you use a snippet engine like LuaSnip, set it up here.
--           expand = function(args)
--             -- Example with LuaSnip:
--             require("luasnip").lsp_expand(args.body)
--           end,
--         },
--         mapping = cmp.mapping.preset.insert({
--           ["<C-b>"] = cmp.mapping.scroll_docs(-4),
--           ["<C-f>"] = cmp.mapping.scroll_docs(4),
--           ["<C-Space>"] = cmp.mapping.complete(),
--           ["<C-e>"] = cmp.mapping.abort(),
--           ["<CR>"] = cmp.mapping.confirm({ select = true }),
--         }),
--         sources = cmp.config.sources({
--           { name = "nvim_lsp" },
--           { name = "buffer" },
--         }),
--       })
--
--       -- Setup completion for the `/` command-line (search)
--       cmp.setup.cmdline("/", {
--         mapping = cmp.mapping.preset.cmdline(),
--         sources = {
--           { name = "buffer" },
--         },
--       })
--
--       -- Setup completion for the `:` command-line (commands)
--       cmp.setup.cmdline(":", {
--         mapping = cmp.mapping.preset.cmdline(),
--         sources = cmp.config.sources({
--           { name = "path" },
--         }, {
--           {
--             name = "cmdline",
--             option = {
--               ignore_cmds = { "Man", "!" },
--             },
--           },
--         }),
--       })
--     end,
--   },
return {
	{
		"hrsh7th/cmp-cmdline",
		config = function()
			local cmp = require("cmp")

			-- Setup completion for the `/` command-line (search)
			cmp.setup.cmdline("/", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = {
					{ name = "buffer" },
				},
			})

			-- Setup completion for the `:` command-line (commands)
			cmp.setup.cmdline(":", {
				mapping = cmp.mapping.preset.cmdline(),
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{
						name = "cmdline",
						option = {
							ignore_cmds = { "Man", "!" },
						},
					},
				}),
			})
		end,
	},
}
