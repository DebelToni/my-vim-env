return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	config = function()
		local config = require("nvim-treesitter.configs")
		config.setup({
			-- ensure_installed = { "lua", "javascript", "typescript", "python", "json", "html", "css", "bash", "yaml", "c", "cpp", "c_sharp", "rust", },
			ensure_installed = { "lua", "python", "json", "html", "css", "bash", "yaml", "c", "cpp", "sql", "java"},
			auto_install = true,
			highlight = { enable = true },
			indent = { enable = true },
		})
	end,
}
