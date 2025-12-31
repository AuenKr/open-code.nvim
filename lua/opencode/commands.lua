---@mod opencode.commands Command registration for opencode.nvim
---@brief [[
--- This module provides command registration and handling for opencode.nvim.
--- It defines user commands and command handlers.
---@brief ]]

local M = {}

--- @type table<string, function> List of available commands and their handlers
M.commands = {}

--- Get visual selection text
--- @return string|nil text Selected text or nil
local function get_visual_selection()
  -- Save current register content and type
  local reg_save = vim.fn.getreg('"')
  local regtype_save = vim.fn.getregtype('"')
  
  -- Reselect visual area and yank to unnamed register
  -- This ensures we capture the selection even if visual mode was just exited
  vim.cmd('normal! ""y')
  
  -- Get content
  local text = vim.fn.getreg('"')
  
  -- Restore register
  vim.fn.setreg('"', reg_save, regtype_save)
  
  return text
end

--- Add text or file to Opencode context
--- @param opencode table The main plugin module
--- @param is_visual boolean True if visual mode selection
function M.add_to_context(opencode, is_visual)
  local cmd_to_send = ''
  
  -- If visual mode, capture selection BEFORE switching context/window
  if is_visual then
    local text = get_visual_selection()
    if text and #text > 0 then
      cmd_to_send = text
    else
      vim.notify('Opencode: No text selected', vim.log.levels.WARN)
      return
    end
  else
    -- Normal mode - add whole file via /add command
    -- We can get this even after switching, but better to get it now
    local file_path = vim.fn.expand('%:.:')
    cmd_to_send = '/add ' .. file_path
  end

  -- Ensure Opencode is open/visible first
  opencode.show()
  
  local current_instance = opencode.opencode.current_instance
  local bufnr = current_instance and opencode.opencode.instances[current_instance]
  
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    vim.notify('Opencode: Failed to activate session.', vim.log.levels.ERROR)
    return
  end

  -- Send command to terminal
  local job_id = vim.b[bufnr].terminal_job_id
  if job_id then
    -- Send text WITHOUT Enter (\r) so user can edit/confirm
    -- Use bracketed paste mode if it's a visual selection to handle large blocks better
    -- and avoid interpretation of special characters
    local text_to_send = cmd_to_send
    if is_visual then
      text_to_send = "\27[200~" .. cmd_to_send .. "\27[201~"
    end

    -- Add a delay to ensure terminal is ready if it was just opened
    -- 300ms should be enough for the process to start receiving input
    vim.defer_fn(function()
      -- Force scroll to bottom and enter insert mode to ensure cursor is at the end
      if vim.api.nvim_buf_is_valid(bufnr) then
        local win_ids = vim.fn.win_findbuf(bufnr)
        if #win_ids > 0 then
          vim.api.nvim_set_current_win(win_ids[1])
          -- Use API to set cursor to bottom (independent of mode)
          local line_count = vim.api.nvim_buf_line_count(bufnr)
          pcall(vim.api.nvim_win_set_cursor, win_ids[1], {line_count, 0})
          -- Ensure insert mode
          vim.cmd('startinsert')
        end
        vim.api.nvim_chan_send(job_id, text_to_send)
      end
    end, 300)
  else
    vim.notify('Opencode: Terminal job not found', vim.log.levels.ERROR)
  end
end

--- Restart Opencode session
--- @param opencode table The main plugin module
function M.restart_session(opencode)
  opencode.restart()
end

--- Register commands for the opencode plugin
--- @param opencode table The main plugin module
function M.register_commands(opencode)
  -- Create the user command for toggling Opencode
  vim.api.nvim_create_user_command('Opencode', function()
    opencode.toggle()
  end, { desc = 'Toggle Opencode terminal' })

  -- Restart command
  vim.api.nvim_create_user_command('OpencodeRestart', function()
    M.restart_session(opencode)
  end, { desc = 'Restart Opencode session' })

  -- Create commands for each command variant (Continue, Verbose)
  for variant_name, variant_args in pairs(opencode.config.command_variants) do
    if variant_args ~= false then
      -- Convert variant name to PascalCase for command name (e.g., "continue" -> "Continue")
      local capitalized_name = variant_name:gsub('^%l', string.upper)
      local cmd_name = 'Opencode' .. capitalized_name

      vim.api.nvim_create_user_command(cmd_name, function()
        opencode.toggle_with_variant(variant_name)
      end, { desc = 'Toggle Opencode terminal with ' .. variant_name .. ' option' })
    end
  end

  -- Add version command
  vim.api.nvim_create_user_command('OpencodeVersion', function()
    vim.notify('Opencode version: ' .. opencode.version(), vim.log.levels.INFO)
  end, { desc = 'Display Opencode version' })
end

return M
