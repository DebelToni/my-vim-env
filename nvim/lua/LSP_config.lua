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
	map("n", "<leader>gd",
		function()
			vim.cmd("keepalt vsplit | wincmd p"); vim.lsp.buf.definition({ reuse_win = true })
		end, "Go to definition; keep current buffer in split")
	map("n", "gr", vim.lsp.buf.references, "References")
	map("n", "K", vim.lsp.buf.hover, "Hover")
	map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
	map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
	map("n", "]d", vim.diagnostic.goto_next, "Next Diagnostic")
	map("n", "[d", vim.diagnostic.goto_prev, "Prev Diagnostic")
	-- Format current buffer
	vim.keymap.set("n", "<leader>gg", function()
		vim.lsp.buf.format({ async = false })
	end, { buffer = bufnr, desc = "LSP: Format buffer" })

	-- Format visual selection (if the server supports range formatting)
	vim.keymap.set("v", "<leader>f", function()
		local s = vim.api.nvim_buf_get_mark(0, "<")
		local e = vim.api.nvim_buf_get_mark(0, ">")
		vim.lsp.buf.format({
			range = {
				start = { line = s[1] - 1, character = s[2] },
				["end"] = { line = e[1] - 1, character = e[2] },
			},
		})
	end, { buffer = bufnr, desc = "LSP: Format selection" })
	-- Make <C-Space> trigger completion on demand (fallback to omnifunc)
	vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
	vim.keymap.set("i", "<C-n>", "<C-x><C-o>", { buffer = bufnr, desc = "LSP: Trigger completion" })
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("my.lsp", { clear = true }),
	callback = my_on_attach,
})

-- =============== Global defaults for servers ===============
-- Advertise proper completion capabilities (snippets, resolve, auto-import edits)
local caps = vim.lsp.protocol.make_client_capabilities()
caps.textDocument = caps.textDocument or {}
caps.textDocument.completion = caps.textDocument.completion or {}
caps.textDocument.completion.completionItem = caps.textDocument.completion.completionItem or {}
caps.textDocument.completion.completionItem.snippetSupport = true
caps.textDocument.completion.completionItem.resolveSupport = {
	properties = { "documentation", "detail", "additionalTextEdits" },
}

vim.lsp.config("*", {
	-- do NOT override with an empty table
	capabilities = caps,
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
	"html",  -- HTML
	"cssls", -- CSS
	"tsserver", -- JS/TS
	"yamlls", -- YAML
	-- "jdtls"     -- java needs its own dir
})
