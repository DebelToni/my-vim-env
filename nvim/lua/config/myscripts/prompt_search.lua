-- promptsearch.lua
-- PromptSearch: quick semantic navigation plugin for Neovim, enhanced with JSON schema

local M = {}

local cfg = {
  endpoint = "http://localhost:11434/api/generate",
  model = "llama3.2:1b",
  max_context_lines = 400,
  temperature = 0,
  timeout = 1000, -- ms
  debug = true,
}

function M.setup(opts)
  cfg = vim.tbl_deep_extend("force", cfg, opts or {})
  vim.api.nvim_create_user_command("PromptSearch", function(params)
    M.prompt_search(params.args)
  end, {
    nargs = "?",
    desc = "Semantic search current buffer via LLM",
  })
end

local function build_context(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local max = math.min(#lines, cfg.max_context_lines)
  local context = {}
  for i = 1, max do
    context[#context + 1] = string.format("%d: %s", i, lines[i])
  end
  return table.concat(context, "\n")
end

local function call_llm(prompt)
  -- Define the JSON schema for structured output
  local schema = {
    type = "object",
    properties = {
      line = { type = "integer" },
    },
    required = { "line" },
  }

  -- Build request body using the 'format' field
  local body = {
    model = cfg.model,
    prompt = prompt,
    stream = false,
    format = schema,
    max_tokens = 4,
    temperature = cfg.temperature,
    stop = { "\n" },
  }

  local json_body = vim.fn.json_encode(body)
  local cmd = {
    "curl", "-sS", "-X", "POST",
    "-H", "Content-Type: application/json",
    "-d", json_body,
    cfg.endpoint,
  }

  -- Execute HTTP request
  local stdout = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("PromptSearch: HTTP request failed", vim.log.levels.ERROR)
    return nil
  end

  -- Decode the top-level JSON response
  local ok, resp = pcall(vim.fn.json_decode, stdout)
  if not ok or type(resp) ~= "table" then
    vim.notify("PromptSearch: JSON decode error", vim.log.levels.ERROR)
    return nil
  end

  -- Parse the structured response, which may be a string or object
  local data
  if resp.response then
    if type(resp.response) == "string" then
      local ok2, parsed = pcall(vim.fn.json_decode, resp.response)
      if ok2 and type(parsed) == "table" then
        data = parsed
      end
    elseif type(resp.response) == "table" then
      data = resp.response
    end
  else
    data = resp
  end

  -- Extract the line number
  local line = data and data.line and tonumber(data.line)
  return line
end

function M.prompt_search(initial_query)
  local bufnr = vim.api.nvim_get_current_buf()
  local query = initial_query
  if not query or #query == 0 then
    query = vim.fn.input("PromptSearch description: ")
  end
  if #query == 0 then return end

  local context = build_context(bufnr)
  local sys_prompt = [[You are a fast code navigation assistant.
Given a source file's numbered lines and a natural language description,
return a JSON object with a single integer property 'line', the 1-based line number matching the description.]]
  local full_prompt = sys_prompt
    .. "\n\nFILE:\n" .. context
    .. "\n\nDescription: " .. query
    .. "\nAnswer in JSON:\n"

  if cfg.debug then
    vim.api.nvim_out_write("[PromptSearch DEBUG] Prompt sent to model:\n" .. full_prompt .. "\n")
  end

  local line_num = call_llm(full_prompt)
	-- print the raw response for debugging
  if cfg.debug then
	vim.api.nvim_out_write("[PromptSearch DEBUG] Model response: " .. tostring(line_num) .. "\n")
  end
  if not line_num then return end

  vim.api.nvim_win_set_cursor(0, {line_num, 0})
  vim.cmd("normal! zz")
end

return M

