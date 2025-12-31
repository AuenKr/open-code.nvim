---@mod opencode.commands Command registration for opencode.nvim
---@brief [[
--- This module provides command registration and handling for opencode.nvim.
--- It defines user commands and command handlers.
---@brief ]]

local M = {}

--- @type table<string, function> List of available commands and their handlers
M.commands = {}

--- Register commands for the opencode plugin
--- @param opencode table The main plugin module
function M.register_commands(opencode)
  -- Create the user command for toggling OpenCode
  vim.api.nvim_create_user_command('OpenCode', function()
    opencode.toggle()
  end, { desc = 'Toggle OpenCode terminal' })

  -- Create commands for each command variant
  for variant_name, variant_args in pairs(opencode.config.command_variants) do
    if variant_args ~= false then
      -- Convert variant name to PascalCase for command name (e.g., "continue" -> "Continue")
      local capitalized_name = variant_name:gsub('^%l', string.upper)
      local cmd_name = 'OpenCode' .. capitalized_name

      vim.api.nvim_create_user_command(cmd_name, function()
        opencode.toggle_with_variant(variant_name)
      end, { desc = 'Toggle OpenCode terminal with ' .. variant_name .. ' option' })
    end
  end

  -- Add version command
  vim.api.nvim_create_user_command('OpenCodeVersion', function()
    vim.notify('OpenCode version: ' .. opencode.version(), vim.log.levels.INFO)
  end, { desc = 'Display OpenCode version' })
end

return M
