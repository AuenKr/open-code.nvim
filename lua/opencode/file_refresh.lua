---@mod opencode.file_refresh File refresh functionality for opencode.nvim
---@brief [[
--- This module provides file refresh functionality to detect and reload files
--- that have been modified by OpenCode or other external processes.
---@brief ]]

local M = {}

--- Timer for checking file changes
--- @type userdata|nil
local refresh_timer = nil

--- Setup autocommands for file change detection
--- @param opencode table The main plugin module
--- @param config table The plugin configuration
function M.setup(opencode, config)
  if not config.refresh.enable then
    return
  end

  local augroup = vim.api.nvim_create_augroup('OpenCodeFileRefresh', { clear = true })

  -- Create an autocommand that checks for file changes more frequently
  vim.api.nvim_create_autocmd({
    'CursorHold',
    'CursorHoldI',
    'FocusGained',
    'BufEnter',
    'InsertLeave',
    'TextChanged',
    'TermLeave',
    'TermEnter',
    'BufWinEnter',
  }, {
    group = augroup,
    pattern = '*',
    callback = function()
      if vim.fn.filereadable(vim.fn.expand '%') == 1 then
        vim.cmd 'checktime'
      end
    end,
    desc = 'Check for file changes on disk',
  })

  -- Clean up any existing timer
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end

  -- Create a timer to check for file changes periodically
  refresh_timer = vim.loop.new_timer()
  if refresh_timer then
    refresh_timer:start(
      0,
      config.refresh.timer_interval,
      vim.schedule_wrap(function()
        -- Only check time if there's an active OpenCode terminal
        local current_instance = opencode.opencode.current_instance
        local bufnr = current_instance and opencode.opencode.instances[current_instance]
        if bufnr and vim.api.nvim_buf_is_valid(bufnr) and #vim.fn.win_findbuf(bufnr) > 0 then
          vim.cmd 'silent! checktime'
        end
      end)
    )
  end

  -- Create an autocommand that notifies when a file has been changed externally
  if config.refresh.show_notifications then
    vim.api.nvim_create_autocmd('FileChangedShellPost', {
      group = augroup,
      pattern = '*',
      callback = function()
        vim.notify('File changed on disk. Buffer reloaded.', vim.log.levels.INFO)
      end,
      desc = 'Notify when a file is changed externally',
    })
  end

  -- Set a shorter updatetime while OpenCode is open
  opencode.opencode.saved_updatetime = vim.o.updatetime

  -- When OpenCode opens, set a shorter updatetime
  vim.api.nvim_create_autocmd('TermOpen', {
    group = augroup,
    pattern = '*',
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match('opencode') then
        opencode.opencode.saved_updatetime = vim.o.updatetime
        vim.o.updatetime = config.refresh.updatetime
      end
    end,
    desc = 'Set shorter updatetime when OpenCode is open',
  })

  -- When OpenCode closes, restore normal updatetime
  vim.api.nvim_create_autocmd('TermClose', {
    group = augroup,
    pattern = '*',
    callback = function()
      local buf_name = vim.api.nvim_buf_get_name(0)
      if buf_name:match('opencode') then
        vim.o.updatetime = opencode.opencode.saved_updatetime
      end
    end,
    desc = 'Restore normal updatetime when OpenCode is closed',
  })
end

--- Clean up the file refresh functionality (stop the timer)
function M.cleanup()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

return M
