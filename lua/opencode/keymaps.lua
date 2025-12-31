---@mod opencode.keymaps Keymap management for opencode.nvim
---@brief [[
--- This module provides keymap registration and handling for opencode.nvim.
--- It handles normal mode, terminal mode, and window navigation keymaps.
---@brief ]]

local M = {}

--- Register keymaps for opencode.nvim
--- @param opencode table The main plugin module
--- @param config table The plugin configuration
function M.register_keymaps(opencode, config)
  local map_opts = { noremap = true, silent = true }

  -- Normal mode toggle keymaps
  if config.keymaps.toggle.normal then
    vim.api.nvim_set_keymap(
      'n',
      config.keymaps.toggle.normal,
      [[<cmd>Opencode<CR>]],
      vim.tbl_extend('force', map_opts, { desc = 'Opencode: Toggle' })
    )
  end

  -- Normal mode restart keymap
  vim.api.nvim_set_keymap(
    'n',
    '<leader>A',
    [[<cmd>OpencodeRestart<CR>]],
    vim.tbl_extend('force', map_opts, { desc = 'Opencode: New Session' })
  )

  -- Visual mode "Add to Context" keymap (<leader>a)
  vim.keymap.set('v', '<leader>a', function()
    require('opencode.commands').add_to_context(opencode, true)
  end, { desc = 'Opencode: Add to Context', noremap = true, silent = true })

  if config.keymaps.toggle.terminal then
    -- Terminal mode toggle keymap
    -- In terminal mode, special keys like Ctrl need different handling
    -- We use a direct escape sequence approach for more reliable terminal mappings
    vim.api.nvim_set_keymap(
      't',
      config.keymaps.toggle.terminal,
      [[<C-\><C-n>:Opencode<CR>]],
      vim.tbl_extend('force', map_opts, { desc = 'Opencode: Toggle' })
    )
  end

  -- Register variant keymaps if configured
  if config.keymaps.toggle.variants then
    for variant_name, keymap in pairs(config.keymaps.toggle.variants) do
      if keymap then
        -- Convert variant name to PascalCase for command name
        local capitalized_name = variant_name:gsub('^%l', string.upper)
        local cmd_name = 'Opencode' .. capitalized_name

        vim.api.nvim_set_keymap(
          'n',
          keymap,
          string.format([[<cmd>%s<CR>]], cmd_name),
          vim.tbl_extend('force', map_opts, { desc = 'Opencode: ' .. capitalized_name })
        )
      end
    end
  end

  -- Register with which-key if it's available
  vim.defer_fn(function()
    local status_ok, which_key = pcall(require, 'which-key')
    if status_ok then
      -- Register normal mode mappings
      which_key.add {
        mode = 'n',
        { '<leader>a', desc = 'Opencode: Toggle', icon = '🤖' },
        { '<leader>A', desc = 'Opencode: New Session', icon = '🔄' },
      }
      
      -- Register visual mode mapping explicitly with icon
      which_key.add {
        mode = 'v',
        { '<leader>a', desc = 'Opencode: Add to Context', icon = '🤖' },
      }

      if config.keymaps.toggle.terminal then
        which_key.add {
          mode = 't',
          { config.keymaps.toggle.terminal, desc = 'Opencode: Toggle', icon = '🤖' },
        }
      end
    end
  end, 100)
end

--- Set up terminal-specific keymaps for window navigation
--- @param opencode table The main plugin module
--- @param config table The plugin configuration
function M.setup_terminal_navigation(opencode, config)
  -- Get current active Opencode instance buffer
  local current_instance = opencode.opencode.current_instance
  local buf = current_instance and opencode.opencode.instances[current_instance]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    -- Create autocommand to enter insert mode when the terminal window gets focus
    local augroup = vim.api.nvim_create_augroup('OpencodeTerminalFocus_' .. buf, { clear = true })

    -- Set up multiple events for more reliable focus detection
    vim.api.nvim_create_autocmd(
      { 'WinEnter', 'BufEnter', 'WinLeave', 'FocusGained', 'CmdLineLeave' },
      {
        group = augroup,
        callback = function()
          vim.schedule(opencode.force_insert_mode)
        end,
        desc = 'Auto-enter insert mode when focusing Opencode terminal',
      }
    )

    -- Add double Esc to exit terminal mode
    vim.api.nvim_buf_set_keymap(
      buf,
      't',
      '<Esc><Esc>',
      [[<C-\><C-n>]],
      { noremap = true, silent = true, desc = 'Exit terminal mode' }
    )

    -- Window navigation keymaps
    if config.keymaps.window_navigation then
      -- Window navigation keymaps with special handling to force insert mode in the target window
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-h>',
        [[<C-\><C-n><C-w>h:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move left' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-j>',
        [[<C-\><C-n><C-w>j:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move down' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-k>',
        [[<C-\><C-n><C-w>k:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move up' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-l>',
        [[<C-\><C-n><C-w>l:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move right' }
      )

      -- Also add normal mode mappings for when user is in normal mode in the terminal
      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-h>',
        [[<C-w>h:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move left' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-j>',
        [[<C-w>j:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move down' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-k>',
        [[<C-w>k:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move up' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        'n',
        '<C-l>',
        [[<C-w>l:lua require("opencode").force_insert_mode()<CR>]],
        { noremap = true, silent = true, desc = 'Window: move right' }
      )
    end

    -- Add scrolling keymaps
    if config.keymaps.scrolling then
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-f>',
        [[<C-\><C-n><C-f>i]],
        { noremap = true, silent = true, desc = 'Scroll full page down' }
      )
      vim.api.nvim_buf_set_keymap(
        buf,
        't',
        '<C-b>',
        [[<C-\><C-n><C-b>i]],
        { noremap = true, silent = true, desc = 'Scroll full page up' }
      )
    end
  end
end

return M
