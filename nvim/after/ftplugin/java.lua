local root_markers = { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }
local root_dir = vim.fs.dirname(vim.fs.find(root_markers, { upward = true })[1]) or vim.fn.getcwd()
local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
local workspace_dir = vim.fn.expand("~/.cache/jdtls/workspace/") .. project_name

vim.lsp.start({
	name = "jdtls",
	cmd = { "jdtls", "-data", workspace_dir },
	root_dir = root_dir,
})
