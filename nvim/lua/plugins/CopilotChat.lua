return {
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		dependencies = {
			{ "github/copilot.vim" },
			{ "nvim-lua/plenary.nvim" },
		},
		build = "make tiktoken",
		-- set split behavior before CopilotChat.setup runs
		config = function(_, opts)
			-- always open vertical splits to the right
			vim.o.splitright = true
			-- if you also want horizontal splits below:
			-- vim.o.splitbelow = true

			-- finally initialize CopilotChat with your opts
			require("CopilotChat").setup(opts)
		end,
		opts = {
			mappings = {
				reset = {
					normal = false,
					-- insert = false,
				},
			},
		},
		keys = {
			{ "<leader>cp", ":CopilotChatOpen<CR>",   desc = "Open CopilotChat" },
			{ "<leader>cm", ":CopilotChatModels<CR>", desc = "Switch Copilot Model" },
		},
	},
}
