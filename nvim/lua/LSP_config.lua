-- Ensure lspconfig is available
local ok = pcall(require, "lspconfig")
if not ok then
	vim.schedule(function()
		vim.notify("nvim-lspconfig not found. Install neovim/nvim-lspconfig and restart.", vim.log.levels.ERROR)
	end)
	return
end

-- =============== UI & diagnostics ===============
vim.diagnostic.config({
	virtual_text     = { spacing = 2, source = "if_many" }, -- 0.11: virtual text is opt-in
	float            = { border = "rounded", source = "if_many" },
	underline        = true,
	update_in_insert = false,
	severity_sort    = true,
})
vim.o.winborder = "rounded"
vim.opt.completeopt:append({ "menuone", "noselect", "popup" })

-- =============== Always-run LSP attach logic ===============
-- Use LspAttach so it runs for every server (even if lspconfig provides its own on_attach)
local function my_on_attach(args)
	local client = vim.lsp.get_client_by_id(args.data.client_id)
	local bufnr  = args.buf
	if not client then return end

	-- Built-in LSP completion (no nvim-cmp)
	if client:supports_method("textDocument/completion") then
		vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
	end

	-- Inlay hints (if supported)
	pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })

	-- Format on save (prefer server formatting)
	if client:supports_method("textDocument/formatting")
		and not client:supports_method("textDocument/willSaveWaitUntil") then
		local grp = vim.api.nvim_create_augroup("lsp-format-" .. bufnr, { clear = true })
		vim.api.nvim_create_autocmd("BufWritePre", {
			group = grp,
			buffer = bufnr,
			callback = function()
				vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = 2000 })
			end,
		})
	end

	-- Keymaps
	local map = function(m, lhs, rhs, desc)
		vim.keymap.set(m, lhs, rhs, { buffer = bufnr, desc = "LSP: " .. desc })
	end
	map("n", "gd", vim.lsp.buf.definition, "Go to definition")
	map("n", "gr", vim.lsp.buf.references, "References")
	map("n", "K", vim.lsp.buf.hover, "Hover")
	map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
	map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
	map("n", "]d", vim.diagnostic.goto_next, "Next Diagnostic")
	map("n", "[d", vim.diagnostic.goto_prev, "Prev Diagnostic")
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("my.lsp", { clear = true }),
	callback = my_on_attach,
})

-- =============== Global defaults for servers ===============
vim.lsp.config("*", {
	capabilities = {}, -- extend later if you add cmp, etc.
})

-- =============== Per-server tweaks ===============
-- Lua
vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			completion = { callSnippet = "Replace" },
			diagnostics = { globals = { "vim" } },
			workspace = { checkThirdParty = false },
			telemetry = { enable = false },
		},
	},
})

-- YAML
vim.lsp.config("yamlls", {
	settings = {
		yaml = {
			keyOrdering = false,
			format = { enable = true },
			validate = true,
			schemaStore = { enable = true, url = "" },
		},
		redhat = { telemetry = { enabled = false } },
	},
})

-- TypeScript/JavaScript
vim.lsp.config("tsserver", {
	settings = {
		typescript = {
			inlayHints = {
				includeInlayParameterNameHints = "all",
				includeInlayVariableTypeHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
			},
		},
		javascript = {
			inlayHints = {
				includeInlayParameterNameHints = "all",
				includeInlayVariableTypeHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
			},
		},
	},
})

-- C/C++ (clangd) -- IMPORTANT: no --clang-tidy until compile DB is present
vim.lsp.config("clangd", {
	cmd = {
		"clangd",
		"--background-index",
		"--header-insertion=iwyu",
		"--query-driver=/usr/bin/clang,/usr/bin/clang++,*/bin/clang,*/bin/clang++",
		-- If your compile DB is in ./build, uncomment:
		-- "--compile-commands-dir=build",
	},
})

-- Python (pyright)
vim.lsp.config("pyright", {
	settings = {
		python = {
			analysis = {
				typeCheckingMode = "basic", -- "off" | "basic" | "strict"
				autoImportCompletions = true,
			},
		},
	},
})

-- =============== Enable servers ===============
vim.lsp.enable({
	"clangd", -- C/C++
	"bashls", -- Bash
	"lua_ls", -- Lua
	"pyright", -- Python
	"html",   -- HTML
	"cssls",  -- CSS
	"tsserver", -- JS/TS
	"yamlls", -- YAML
	-- "jdtls"     -- see ftplugin below
})

-- =============== Java (jdtls) ===============
-- Put this file at:  after/ftplugin/java.lua
--[[
local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
local root_dir = vim.fs.dirname(vim.fs.find(root_markers, { upward = true })[1]) or vim.fn.getcwd()
local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
local workspace_dir = vim.fn.expand("~/.cache/jdtls/workspace/") .. project_name

vim.lsp.start({
  name = "jdtls",
  cmd = { "jdtls", "-data", workspace_dir },
  root_dir = root_dir,
})
]]
