-- ──────────────────────────────────────────────────────────────────────────────
--  <leader>rc  – strip comments in .c/.h and .py buffers
--               • keeps original blank lines
--               • removes lines that were *pure* comments
-- ──────────────────────────────────────────────────────────────────────────────
local function trim_right(s) return (s:gsub("%s+$", "")) end

--------------------------------------------------------------------------------
-- C helpers (//  and  /* … */)
--------------------------------------------------------------------------------
local function strip_c(lines)
  local out, in_block = {}, false
  for _, ln in ipairs(lines) do
    local i, cleaned = 1, ""
    while i <= #ln do
      if in_block then
        local s, e = ln:find("*/", i, true)
        if s then in_block, i = false, e + 1 else break end
      else
        local s_sl  = ln:find("//", i, true)
        local s_blk = ln:find("/*", i, true)
        if s_sl and (not s_blk or s_sl < s_blk) then
          cleaned = cleaned .. ln:sub(i, s_sl - 1)
          break
        elseif s_blk then
          cleaned = cleaned .. ln:sub(i, s_blk - 1)
          in_block, i = true, s_blk + 2
        else
          cleaned = cleaned .. ln:sub(i)
          break
        end
      end
    end
    table.insert(out, cleaned)
  end
  return out
end

--------------------------------------------------------------------------------
-- Python helpers  (# … and  ''' / """ …)
--------------------------------------------------------------------------------
local function strip_python(lines)
  local out = {}
  -- local in_block, delim = false, nil
  for _, ln in ipairs(lines) do
    local cur = ln
    -- if in_block then
    --   local stop = cur:find(delim, 1, true)
    --   if stop then cur = cur:sub(stop + 3); in_block = false else cur = "" end
    -- end
    -- if not in_block then
      -- local p1, p2 = cur:find("'''", 1, true), cur:find('"""', 1, true)
      -- local p, d = nil, nil
      -- if p1 and (not p2 or p1 < p2) then p, d = p1, "'''" end
      -- if p2 and (not p1 or p2 < p1) then p, d = p2, '"""' end
      -- if p then
      --   local before, after = cur:sub(1, p - 1), cur:sub(p + 3)
      --   local close = after:find(d, 1, true)
      --   if close then
      --     cur = before .. after:sub(close + 3)
      --   else
      --     cur, in_block, delim = before, true, d
      --   end
      -- end
      local h = cur:find("#")
      if h then cur = cur:sub(1, h - 1) end
    -- end
    table.insert(out, cur)
  end
  return out
end

--------------------------------------------------------------------------------
-- Main dispatcher – keeps original blanks
--------------------------------------------------------------------------------
local function remove_comments()
  local ext   = vim.fn.expand("%:e")
  local buf   = 0
  local orig  = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local cleaned

  if ext == "c" or ext == "h" then
    cleaned = strip_c(orig)
  elseif ext == "py" then
    cleaned = strip_python(orig)
  elseif ext == "yml" or ext == "yaml" then
	cleaned = strip_python(orig)
  else
    vim.notify("remove-comments: unsupported extension “" .. ext .. "”", vim.log.levels.WARN)
    return
  end

  local final = {}
  for i, ln in ipairs(cleaned) do
    local trimmed = trim_right(ln)
    local was_blank = orig[i]:match("^%s*$")          -- true if line was already empty
    if trimmed == "" then
      if was_blank then                               -- keep pre-existing blank line
        table.insert(final, "")
      else
        -- line was pure comment → drop
      end
    else                                              -- keep line with code/content
      table.insert(final, trimmed)
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, final)
  vim.notify("Comments removed.", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Key mapping
--------------------------------------------------------------------------------
vim.keymap.set("n", "<leader>rc", remove_comments,
  { desc = "Remove comments from buffer (C/Python)", noremap = true, silent = true })

