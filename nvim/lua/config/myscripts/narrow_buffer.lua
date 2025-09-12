-- ~/.config/nvim/lua/narrow.lua
local M = {}

-- One namespace for all narrows; extmarks keep the target region "attached"
local NS = vim.api.nvim_create_namespace("narrow")

-- Helper: safe number
local function to_int(x) return tonumber(x or "") end

-- Core: create a narrowed buffer linked to a region in the original buffer
local function create_narrow(orig_buf, start_lnum, end_lnum)
  -- Normalize and bounds-check
  if end_lnum < start_lnum then start_lnum, end_lnum = end_lnum, start_lnum end
  local last = vim.api.nvim_buf_line_count(orig_buf)
  start_lnum = math.max(1, math.min(start_lnum, last))
  end_lnum   = math.max(1, math.min(end_lnum, last))

  -- Grab lines [start..end] inclusive from original
  local slice = vim.api.nvim_buf_get_lines(orig_buf, start_lnum - 1, end_lnum, false)

  -- Create narrowed buffer (listed, but with acwrite so we can intercept :w)
  local nar_buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(nar_buf, 0, -1, false, slice)

  -- Mirror filetype; disable swapfile; mark as acwrite; clean up when closed
  vim.bo[nar_buf].filetype  = vim.bo[orig_buf].filetype
  vim.bo[nar_buf].buftype   = "acwrite"
  vim.bo[nar_buf].bufhidden = "wipe"
  vim.bo[nar_buf].swapfile  = false

  -- Name the buffer so it’s obvious what you’re editing
  local orig_name = vim.api.nvim_buf_get_name(orig_buf)
  if orig_name == "" then orig_name = "[No Name]" end
  local nar_name = string.format("[narrow] %s:%d-%d", orig_name, start_lnum, end_lnum)
  pcall(vim.api.nvim_buf_set_name, nar_buf, nar_name)

  -- Extmarks to track moving start/end in the original while you edit elsewhere.
  -- start mark: before region (right_gravity=false)
  -- end   mark: after  region (right_gravity=true) and set one line past end to make it exclusive
  local start_mark = vim.api.nvim_buf_set_extmark(orig_buf, NS, start_lnum - 1, 0, { right_gravity = false })
  local end_mark   = vim.api.nvim_buf_set_extmark(orig_buf, NS, end_lnum, 0,     { right_gravity = true  })

  -- Stash linkage in buffer-local table
  vim.b[nar_buf].narrow = {
    orig_buf   = orig_buf,
    start_mark = start_mark,
    end_mark   = end_mark,
  }

  -- Intercept :w in the narrowed buffer and splice back into the original region
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = nar_buf,
    callback = function(ev)
      local link = vim.b[ev.buf].narrow
      if not link then return end
      local o = link.orig_buf
      if not vim.api.nvim_buf_is_loaded(o) then
        vim.notify("Original buffer is not loaded; cannot write back", vim.log.levels.ERROR)
        return
      end

      -- Where are the region boundaries *now* in the original?
      local s = vim.api.nvim_buf_get_extmark_by_id(o, NS, link.start_mark, {})
      local e = vim.api.nvim_buf_get_extmark_by_id(o, NS, link.end_mark, {})
      if not s or not e or #s == 0 or #e == 0 then
        vim.notify("Narrow: lost region marks; aborting write", vim.log.levels.ERROR)
        return
      end
      local srow = s[1]      -- inclusive, 0-based
      local erow = e[1]      -- exclusive, 0-based (we placed end mark on the line after)

      -- Get new content from narrowed buffer
      local new_lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)

      -- Replace region [srow, erow) with new_lines
      vim.api.nvim_buf_set_lines(o, srow, erow, false, new_lines)

      -- Save the original buffer to disk
      vim.api.nvim_buf_call(o, function()
        -- keepjumps/keepalt to avoid messing with user state
        vim.cmd("silent keepjumps keepalt write")
      end)

      -- Mark narrowed buffer unmodified and echo a friendly message
      vim.bo[ev.buf].modified = false
      vim.notify(string.format("Narrow: wrote %d line(s) back to %s",
        #new_lines, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(o), ":.")))
    end,
  })

  -- Open the narrowed buffer in the current window
  vim.api.nvim_set_current_buf(nar_buf)
end

-- :Narrow [start end]  or use visual range:  :'<,'>Narrow
M.setup = function()
  vim.api.nvim_create_user_command("Narrow", function(opts)
    local orig_buf = vim.api.nvim_get_current_buf()

    local start_lnum, end_lnum
    if opts.range ~= 0 then
      start_lnum, end_lnum = opts.line1, opts.line2
    else
      start_lnum = to_int(opts.fargs[1])
      end_lnum   = to_int(opts.fargs[2])
    end

    if not (start_lnum and end_lnum) then
      vim.notify("Usage: :Narrow {start} {end}  or visually select lines then :Narrow", vim.log.levels.WARN)
      return
    end

    create_narrow(orig_buf, start_lnum, end_lnum)
  end, { nargs = "*", range = true, desc = "Edit a slice of the current buffer in a narrowed view" })
end

return M

