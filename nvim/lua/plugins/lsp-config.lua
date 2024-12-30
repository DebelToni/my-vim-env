return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"lua_ls",
					"jdtls",
					"html",
					"cssls",
					"jsonls",
					"ts_ls",
					"yamlls",
					"dockerls",
					"bashls",
					"vimls",
					"pyright",
					"clangd",
					-- future reference: https://github.com/williamboman/mason-lspconfig.nvim
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
			local lspconfig = require("lspconfig")
			lspconfig.lua_ls.setup({})
			lspconfig.jdtls.setup({capabilities = capabilities})
			lspconfig.html.setup({capabilities = capabilities})
			lspconfig.cssls.setup({capabilities = capabilities})
			lspconfig.jsonls.setup({capabilities = capabilities})
			lspconfig.ts_ls.setup({capabilities = capabilities})
			lspconfig.yamlls.setup({capabilities = capabilities})
			lspconfig.dockerls.setup({capabilities = capabilities})
			lspconfig.bashls.setup({capabilities = capabilities})
			lspconfig.vimls.setup({capabilities = capabilities})
			lspconfig.pyright.setup({capabilities = capabilities})
			lspconfig.clangd.setup({capabilities = capabilities})
			vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, { desc = "Code Action" })
			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover" })
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to Definition" })
		end,
	},
}
