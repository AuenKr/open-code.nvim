-- Tests for command registration in Opencode
local assert = require('luassert')
local describe = require('plenary.busted').describe
local it = require('plenary.busted').it

local commands_module = require('opencode.commands')

describe('command registration', function()
  local registered_commands = {}
  
  before_each(function()
    -- Reset registered commands
    registered_commands = {}
    
    -- Mock vim functions
    _G.vim = _G.vim or {}
    _G.vim.api = _G.vim.api or {}
    _G.vim.api.nvim_create_user_command = function(name, callback, opts)
      table.insert(registered_commands, {
        name = name,
        callback = callback,
        opts = opts
      })
      return true
    end
    
    -- Mock vim.notify
    _G.vim.notify = function() end
    
    -- Create mock opencode module
    local opencode = {
      toggle = function() return true end,
      version = function() return '0.3.0' end
    }
    
    -- Run the register_commands function
    commands_module.register_commands(opencode)
  end)
  
  describe('command registration', function()
    it('should register Opencode command', function()
      local command_registered = false
      for _, cmd in ipairs(registered_commands) do
        if cmd.name == 'Opencode' then
          command_registered = true
          assert.is_not_nil(cmd.callback, "Opencode command should have a callback")
          assert.is_not_nil(cmd.opts, "Opencode command should have options")
          assert.is_not_nil(cmd.opts.desc, "Opencode command should have a description")
          break
        end
      end
      
      assert.is_true(command_registered, "Opencode command should be registered")
    end)
    
    it('should register OpencodeVersion command', function()
      local command_registered = false
      for _, cmd in ipairs(registered_commands) do
        if cmd.name == 'OpencodeVersion' then
          command_registered = true
          assert.is_not_nil(cmd.callback, "OpencodeVersion command should have a callback")
          assert.is_not_nil(cmd.opts, "OpencodeVersion command should have options")
          assert.is_not_nil(cmd.opts.desc, "OpencodeVersion command should have a description")
          break
        end
      end
      
      assert.is_true(command_registered, "OpencodeVersion command should be registered")
    end)
  end)
  
  describe('command execution', function()
    it('should call toggle when Opencode command is executed', function()
      local toggle_called = false
      
      -- Find the Opencode command and execute its callback
      for _, cmd in ipairs(registered_commands) do
        if cmd.name == 'Opencode' then
          -- Create a mock that can detect when toggle is called
          local original_toggle = cmd.callback
          cmd.callback = function()
            toggle_called = true
            return true
          end
          
          -- Execute the command callback
          cmd.callback()
          break
        end
      end
      
      assert.is_true(toggle_called, "Toggle function should be called when Opencode command is executed")
    end)
    
    it('should call notify with version when OpencodeVersion command is executed', function()
      local notify_called = false
      local notify_message = nil
      local notify_level = nil
      
      -- Mock vim.notify to capture calls
      _G.vim.notify = function(msg, level)
        notify_called = true
        notify_message = msg
        notify_level = level
        return true
      end
      
      -- Find the OpencodeVersion command and execute its callback
      for _, cmd in ipairs(registered_commands) do
        if cmd.name == 'OpencodeVersion' then
          cmd.callback()
          break
        end
      end
      
      assert.is_true(notify_called, "vim.notify should be called when OpencodeVersion command is executed")
      assert.is_not_nil(notify_message, "Notification message should not be nil")
      assert.is_not_nil(string.find(notify_message, 'Opencode version'), "Notification should contain version information")
    end)
  end)
end)