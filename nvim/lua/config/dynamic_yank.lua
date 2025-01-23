-- Define the module
local M = {}

-- Path to the shared yank file
local yank_file = "/tmp/nvim-yank"

-- Timer for dynamic syncing
local timer = nil

-- Function to save yanked text to the shared file
local function save_yank_to_file()
  if vim.v.event.operator == 'y' then
    local yank_text = vim.fn.getreg('"') -- Get the default register content
    vim.fn.writefile({ yank_text }, yank_file) -- Write to the shared file
  end
end

-- Function to sync register from the shared file
local function sync_register_from_file()
  if vim.fn.filereadable(yank_file) == 1 then
    local yank_text = vim.fn.readfile(yank_file) -- Read from the shared file
    vim.fn.setreg('"', table.concat(yank_text, "\n")) -- Set it back to the default register
  end
end

-- Function to start the dynamic yank functionality
function M.start()
  -- Create an augroup for the yank autocmd
  vim.api.nvim_create_augroup("DynamicYank", { clear = true })

  -- Save yanked text to file on TextYankPost
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = "DynamicYank",
    callback = save_yank_to_file,
  })

  -- Start the timer to periodically sync registers
  if not timer then
    timer = vim.loop.new_timer()
    timer:start(0, 1000, vim.schedule_wrap(sync_register_from_file))
    print("Dynamic yank syncing started.")
  end
end

-- Function to stop the dynamic yank functionality
function M.stop()
  -- Clear the augroup to stop saving yanked text
  vim.api.nvim_clear_autocmds({ group = "DynamicYank" })

  -- Stop the timer if it's running
  if timer then
    timer:stop()
    timer:close()
    timer = nil
    print("Dynamic yank syncing stopped.")
  end
end

-- Toggle the dynamic yank functionality
function M.toggle()
  if timer then
    M.stop()
  else
    M.start()
  end
end

-- Expose a command to toggle the functionality
vim.api.nvim_create_user_command("ToggleDynamicYank", M.toggle, {})

return M

