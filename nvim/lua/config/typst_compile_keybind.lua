-- <leader>ct: Typst compile current buffer and open resulting PDF (notify on errors)
local function typst_compile_and_open()
	local bufnr = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(bufnr)

	if file == "" then
		vim.notify("Typst: buffer has no file path (save it first).", vim.log.levels.ERROR)
		return
	end

	if vim.bo[bufnr].filetype ~= "typst" and not file:match("%.typ$") then
		vim.notify(("Typst: not a .typ buffer (%s)."):format(file), vim.log.levels.ERROR)
		return
	end

	if vim.bo[bufnr].modified then
		local ok, err = pcall(vim.cmd, "write")
		if not ok then
			vim.notify(("Typst: failed to write file:\n%s"):format(err), vim.log.levels.ERROR)
			return
		end
	end

	local pdf = file:gsub("%.typ$", ".pdf")

	local function strip_ansi(s)
		if not s then return "" end
		-- Strip ANSI escape sequences (colors, etc.)
		return s:gsub("\27%[[0-9;]*m", ""):gsub("\r", "")
	end

	local function open_pdf(path)
		local open_cmd
		if vim.fn.has("mac") == 1 then
			open_cmd = { "open", path }
		elseif vim.fn.has("win32") == 1 then
			open_cmd = { "cmd.exe", "/c", "start", "", path }
		else
			open_cmd = { "xdg-open", path }
		end

		if vim.system then
			vim.system(open_cmd, { detach = true })
		else
			vim.fn.jobstart(open_cmd, { detach = true })
		end
	end

	-- NOTE: removed unsupported "--color never"
	local cmd = { "typst", "compile", file, pdf }

	-- Optional: reduce/disable colored output in many CLIs
	local env = {
		NO_COLOR = "1",
		TERM = "dumb",
	}

	if vim.system then
		vim.system(cmd, { text = true, env = env }, function(res)
			if res.code ~= 0 then
				local msg = (res.stderr and res.stderr ~= "") and res.stderr or (res.stdout or "Unknown Typst error.")
				msg = strip_ansi(msg)
				vim.schedule(function()
					vim.notify(("Typst compile failed:\n%s"):format(msg), vim.log.levels.ERROR)
				end)
				return
			end

			vim.schedule(function()
				open_pdf(pdf)
			end)
		end)
	else
		local stdout, stderr = {}, {}
		local job_id = vim.fn.jobstart(cmd, {
			stdout_buffered = true,
			stderr_buffered = true,
			env = env,
			on_stdout = function(_, data)
				if data then vim.list_extend(stdout, data) end
			end,
			on_stderr = function(_, data)
				if data then vim.list_extend(stderr, data) end
			end,
			on_exit = function(_, code)
				if code ~= 0 then
					local msg = table.concat(stderr, "\n")
					if msg == "" then msg = table.concat(stdout, "\n") end
					if msg == "" then msg = "Unknown Typst error." end
					msg = strip_ansi(msg)
					vim.schedule(function()
						vim.notify(("Typst compile failed:\n%s"):format(msg), vim.log.levels.ERROR)
					end)
					return
				end

				vim.schedule(function()
					open_pdf(pdf)
				end)
			end,
		})

		if job_id <= 0 then
			vim.notify("Typst: failed to start compile job (is `typst` in $PATH?).", vim.log.levels.ERROR)
		end
	end
end

vim.keymap.set("n", "<leader>ct", typst_compile_and_open, { desc = "Typst: compile & open PDF" })
