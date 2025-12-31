-- Tests for new features in Opencode
local assert = require('luassert')
local describe = require('plenary.busted').describe
local it = require('plenary.busted').it

local commands = require('opencode.commands')
local keymaps = require('opencode.keymaps')
local terminal = require('opencode.terminal')

describe('features', function()
  local registered_commands = {}
  local mapped_keys = {}
  local buffer_options = {}
  local vim_cmd_calls = {}
  
  before_each(function()
    registered_commands = {}
    mapped_keys = {}
    buffer_options = {}
    vim_cmd_calls = {}
    
    -- Mock vim global
    _G.vim = _G.vim or {}
    _G.vim.api = _G.vim.api or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.o = { columns = 100, lines = 100, cmdheight = 1 }
    
    -- Mock commands
    _G.vim.api.nvim_create_user_command = function(name, callback, opts)
      table.insert(registered_commands, { name = name, callback = callback, opts = opts })
    end
    
    -- Mock keymaps
    _G.vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
      table.insert(mapped_keys, { mode = mode, lhs = lhs, rhs = rhs, opts = opts })
    end
    _G.vim.keymap = {
      set = function(modes, lhs, rhs, opts)
        if type(modes) == 'string' then modes = {modes} end
        for _, mode in ipairs(modes) do
          table.insert(mapped_keys, { mode = mode, lhs = lhs, rhs = rhs, opts = opts })
        end
      end
    }
    
    -- Mock buffer keymaps
    _G.vim.api.nvim_buf_set_keymap = function(bufnr, mode, lhs, rhs, opts)
      table.insert(mapped_keys, { bufnr = bufnr, mode = mode, lhs = lhs, rhs = rhs, opts = opts })
    end
    
    -- Mock buffer options
    _G.vim.api.nvim_set_option_value = function(name, value, opts)
      if opts and opts.buf then
        buffer_options[opts.buf] = buffer_options[opts.buf] or {}
        buffer_options[opts.buf][name] = value
      end
    end
    _G.vim.api.nvim_get_option_value = function() return '' end
    
    -- Mock commands
    _G.vim.cmd = function(cmd)
      table.insert(vim_cmd_calls, cmd)
    end
    
    -- Mock other API
    _G.vim.api.nvim_create_buf = function() return 1 end
    _G.vim.api.nvim_open_win = function() return 1 end
    _G.vim.api.nvim_win_set_buf = function() end
    _G.vim.api.nvim_buf_set_name = function() end
    _G.vim.api.nvim_buf_is_valid = function() return true end
    _G.vim.api.nvim_get_current_win = function() return 1 end
    _G.vim.api.nvim_create_augroup = function() return 1 end
    _G.vim.api.nvim_create_autocmd = function() end
    
    _G.vim.fn.bufnr = function() return 1 end
    _G.vim.fn.getcwd = function() return '/test' end
    _G.vim.fn.shellescape = function(s) return "'" .. s .. "'" end
    _G.vim.fn.termopen = function() return 1 end
    _G.vim.fn.jobwait = function() return {-1} end
    _G.vim.fn.win_findbuf = function() return {} end
    
    -- Mock defer_fn
    _G.vim.defer_fn = function(cb) cb() end
  end)
  
  describe('Commands', function()
    it('should register OpencodeRestart command', function()
      local opencode_mock = { config = { command_variants = {} }, toggle = function() end, restart = function() end }
      commands.register_commands(opencode_mock)
      
      local found = false
      for _, cmd in ipairs(registered_commands) do
        if cmd.name == 'OpencodeRestart' then
          found = true
          break
        end
      end
      assert.is_true(found, 'OpencodeRestart should be registered')
    end)
  end)
  
  describe('Context', function()
    it('should send file path in normal mode', function()
      local opencode_mock = { 
        opencode = { instances = { test = 1 }, current_instance = 'test' },
        show = function() end 
      }
      
      -- Mock expand
      _G.vim.fn.expand = function() return 'test.lua' end
      _G.vim.b = { [1] = { terminal_job_id = 100 } }
      
      -- Mock chan_send
      local sent_data = nil
      _G.vim.api.nvim_chan_send = function(id, data)
        if id == 100 then sent_data = data end
      end
      
      commands.add_to_context(opencode_mock, false)
      
      assert.are.equal('/add test.lua', sent_data)
    end)
    
    it('should send selected text in visual mode', function()
      local opencode_mock = { 
        opencode = { instances = { test = 1 }, current_instance = 'test' },
        show = function() end 
      }
      
      -- Mock getreg
      _G.vim.fn.getreg = function() return 'selected text' end
      _G.vim.b = { [1] = { terminal_job_id = 100 } }
      
      -- Mock chan_send
      local sent_data = nil
      _G.vim.api.nvim_chan_send = function(id, data)
        if id == 100 then sent_data = data end
      end
      
      commands.add_to_context(opencode_mock, true)
      
      -- Wait for deferred function
      -- Since we mocked defer_fn to execute immediately in setup, it should run
      
      -- Expect bracketed paste
      assert.are.equal('\27[200~selected text\27[201~', sent_data)
    end)
  end)

  describe('Keymaps', function()
    it('should register <leader>a visual keymap', function()
      local opencode_mock = {}
      local config = { 
        keymaps = { 
          toggle = { normal = '<leader>a', terminal = '<C-o>', variants = {} },
          window_navigation = true
        } 
      }
      keymaps.register_keymaps(opencode_mock, config)
      
      local found = false
      for _, map in ipairs(mapped_keys) do
        if map.lhs == '<leader>a' and map.mode == 'v' then
          found = true
          break
        end
      end
      assert.is_true(found, '<leader>a (visual) should be registered')
    end)
    
    it('should register double escape in terminal', function()
      local opencode_mock = { opencode = { instances = {}, current_instance = 'test' } }
      opencode_mock.opencode.instances['test'] = 1
      local config = { keymaps = { window_navigation = true, scrolling = true } }
      
      keymaps.setup_terminal_navigation(opencode_mock, config)
      
      local found = false
      for _, map in ipairs(mapped_keys) do
        if map.bufnr == 1 and map.lhs == '<Esc><Esc>' and map.rhs:match('C%-\\><C%-n') then
          found = true
          break
        end
      end
      assert.is_true(found, '<Esc><Esc> should be registered in terminal buffer')
    end)
  end)
  
  describe('Buffer visibility', function()
    it('should set buflisted to false for terminal buffer', function()
      local opencode_mock = { opencode = { instances = {} } }
      local config = { 
        window = { position = 'botright', split_ratio = 0.5, enter_insert = true },
        git = { multi_instance = false, use_git_root = false },
        shell = { separator = '&&', pushd_cmd = 'cd', popd_cmd = 'cd -' },
        command = 'opencode'
      }
      local git_mock = {}
      
      terminal.toggle(opencode_mock, config, git_mock)
      
      -- Check if setlocal nobuflisted was called (for split windows)
      local setlocal_called = false
      for _, cmd in ipairs(vim_cmd_calls) do
        if cmd == 'setlocal nobuflisted' then
          setlocal_called = true
          break
        end
      end
      assert.is_true(setlocal_called, 'setlocal nobuflisted command should be called')
    end)
  end)
end)
