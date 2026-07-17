local M = {}

local ns = vim.api.nvim_create_namespace("ReloadDiffHighlight")

M.config = {
	hl_group = "ReloadDiffHighlightAdd",
	clear_on_edit = true,
}

local ready = {}
local before = {}
local last_text = {}

local function buf_valid(bufnr)
	return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function buf_text(bufnr)
	return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local function clear(bufnr)
	if buf_valid(bufnr) then
		vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
	end
end

local function line_counts(lines, start_lnum, count)
	local counts = {}
	for i = 0, count - 1 do
		local text = lines[start_lnum + i] or ""
		counts[text] = (counts[text] or 0) + 1
	end
	return counts
end

local function common_counts(old_lines, new_lines, old_start, old_count, new_start, new_count)
	local old_counts = line_counts(old_lines, old_start, old_count)
	local new_counts = line_counts(new_lines, new_start, new_count)
	local common = {}
	for text, old_count_for_text in pairs(old_counts) do
		local new_count_for_text = new_counts[text]
		if new_count_for_text then
			common[text] = math.min(old_count_for_text, new_count_for_text)
		end
	end
	return common
end

local function take_common(common, text)
	if (common[text] or 0) <= 0 then return false end
	common[text] = common[text] - 1
	return true
end

local function highlight_changed_new_lines(bufnr, old_text, new_text)
	clear(bufnr)
	if old_text == new_text then return end

	local ok, hunks = pcall(vim.diff, old_text, new_text, {
		result_type = "indices",
		algorithm = "histogram",
	})
	if not ok or type(hunks) ~= "table" then return end

	local old_lines = vim.split(old_text, "\n", { plain = true })
	local new_lines = vim.split(new_text, "\n", { plain = true })
	local line_count = math.max(1, vim.api.nvim_buf_line_count(bufnr))

	for _, hunk in ipairs(hunks) do
		local old_start, old_count, new_start, new_count = hunk[1], hunk[2], hunk[3], hunk[4]

		while old_count > 0 and new_count > 0 and old_lines[old_start] == new_lines[new_start] do
			old_start = old_start + 1
			new_start = new_start + 1
			old_count = old_count - 1
			new_count = new_count - 1
		end
		while old_count > 0 and new_count > 0 and old_lines[old_start + old_count - 1] == new_lines[new_start + new_count - 1] do
			old_count = old_count - 1
			new_count = new_count - 1
		end

		if new_count > 0 then
			local common = common_counts(old_lines, new_lines, old_start, old_count, new_start, new_count)
			for i = 0, new_count - 1 do
				local text = new_lines[new_start + i] or ""
				if not take_common(common, text) then
					local row = math.max(0, math.min(new_start + i - 1, line_count - 1))
					vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
						line_hl_group = M.config.hl_group,
					})
				end
			end
		end
	end
end

function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
	pcall(vim.api.nvim_set_hl, 0, M.config.hl_group, { link = "DiffAdd", default = true })

	local group = vim.api.nvim_create_augroup("ReloadDiffHighlight", { clear = true })

	vim.api.nvim_create_autocmd("BufReadPre", {
		group = group,
		callback = function(ev)
			if ready[ev.buf] then
				local text = buf_text(ev.buf)
				if text ~= "" then before[ev.buf] = text end
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function(ev)
			local new_text = buf_text(ev.buf)
			local old_text = before[ev.buf] or (ready[ev.buf] and last_text[ev.buf])
			before[ev.buf] = nil
			ready[ev.buf] = true
			last_text[ev.buf] = new_text
			if old_text then
				highlight_changed_new_lines(ev.buf, old_text, new_text)
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave", "BufWritePost" }, {
		group = group,
		callback = function(ev)
			if ready[ev.buf] then last_text[ev.buf] = buf_text(ev.buf) end
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(ev)
			ready[ev.buf] = nil
			before[ev.buf] = nil
			last_text[ev.buf] = nil
		end,
	})

	if M.config.clear_on_edit then
		vim.api.nvim_create_autocmd({ "InsertEnter", "TextChanged", "TextChangedI" }, {
			group = group,
			callback = function(ev) clear(ev.buf) end,
		})
	end
end

return M
