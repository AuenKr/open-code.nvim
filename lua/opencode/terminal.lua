---@mod opencode.terminal Terminal management for opencode.nvim
---@brief [[
--- This module provides terminal buffer management for opencode.nvim.
--- It handles creating, toggling, and managing the terminal window.
---@brief ]]

local M = {}

--- Terminal buffer and window management
-- @table OpencodeTerminal
-- @field instances table Key-value store of git root to buffer number
-- @field saved_updatetime number|nil Original updatetime before Opencode was opened
-- @field current_instance string|nil Current git root path for active instance
M.terminal = {
  instances = {},
  saved_updatetime = nil,
  current_instance = nil,
}

--- Get the current git root or a fallback identifier
--- @param git table The git module
--- @return string identifier Git root path or fallback identifier
local function get_instance_identifier(git)
  local git_root = git.get_git_root()
  if git_root then
    return git_root
  else
    -- Fallback to current working directory if not in a git repo
    return vim.fn.getcwd()
  end
end

--- Calculate floating window dimensions from percentage strings
--- @param value number|string Dimension value (number or percentage string)
--- @param max_value number Maximum value (columns or lines)
--- @return number Calculated dimension
--- @private
local function calculate_float_dimension(value, max_value)
  if value == nil then
    return math.floor(max_value * 0.8) -- Default to 80% if not specified
  elseif type(value) == 'string' and value:match('^%d+%%$') then
    local percentage = tonumber(value:match('^(%d+)%%$'))
    return math.floor(max_value * percentage / 100)
  end
  return value
end

--- Calculate floating window position for centering
--- @param value number|string Position value (number, "center", or percentage)
--- @param window_size number Size of the window
--- @param max_value number Maximum value (columns or lines)
--- @return number Calculated position
--- @private
local function calculate_float_position(value, window_size, max_value)
  local pos
  if value == 'center' then
    pos = math.floor((max_value - window_size) / 2)
  elseif type(value) == 'string' and value:match('^%d+%%$') then
    local percentage = tonumber(value:match('^(%d+)%%$'))
    pos = math.floor(max_value * percentage / 100)
  else
    pos = value or 0
  end
  -- Clamp position to ensure window is visible
  return math.max(0, math.min(pos, max_value - window_size))
end

--- Create a floating window for Opencode
--- @param config table Plugin configuration containing window settings
--- @param existing_bufnr number|nil Buffer number of existing buffer to show in the float (optional)
--- @return number Window ID of the created floating window
--- @private
local function create_float(config, existing_bufnr)
  local float_config = config.window.float or {}

  -- Get editor dimensions (accounting for command line, status line, etc.)
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines - vim.o.cmdheight - 1 -- Subtract command line and status line

  -- Calculate dimensions
  local width = calculate_float_dimension(float_config.width, editor_width)
  local height = calculate_float_dimension(float_config.height, editor_height)

  -- Calculate position
  local row = calculate_float_position(float_config.row, height, editor_height)
  local col = calculate_float_position(float_config.col, width, editor_width)

  -- Create floating window configuration
  local win_config = {
    relative = float_config.relative or 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = float_config.border or 'rounded',
    style = 'minimal',
  }

  -- Create buffer if we don't have an existing one
  local bufnr = existing_bufnr
  if not bufnr then
    bufnr = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
    vim.api.nvim_set_option_value('buflisted', false, { buf = bufnr })
  else
    -- Validate existing buffer is still valid and a terminal
    if not vim.api.nvim_buf_is_valid(bufnr) then
      bufnr = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
      vim.api.nvim_set_option_value('buflisted', false, { buf = bufnr })
    else
      local buftype = vim.api.nvim_get_option_value('buftype', {buf = bufnr})
      if buftype ~= 'terminal' then
        -- Buffer exists but is no longer a terminal, create a new one
        bufnr = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
        vim.api.nvim_set_option_value('buflisted', false, { buf = bufnr })
      end
    end
  end

  -- Create and return the floating window
  return vim.api.nvim_open_win(bufnr, true, win_config)
end

--- Build command with git root directory if configured
--- @param config table Plugin configuration
--- @param git table Git module
--- @param base_cmd string Base command to run
--- @return string Command with git root directory change if applicable
--- @private
local function build_command_with_git_root(config, git, base_cmd)
  local target_dir = vim.fn.getcwd()
  
  if config.git and config.git.use_git_root then
    local git_root = git.get_git_root()
    if git_root then
      target_dir = git_root
    end
  end

  local quoted_dir = vim.fn.shellescape(target_dir)
  -- Use configurable shell commands
  local separator = config.shell.separator
  local pushd_cmd = config.shell.pushd_cmd
  local popd_cmd = config.shell.popd_cmd
  
  -- Explicitly pass path as positional argument to overwrite any sticky session behavior
  -- We assume base_cmd (e.g. 'opencode') accepts project path as argument
  -- If base_cmd already has args, we append directory
  local cmd_with_cwd = base_cmd .. ' ' .. quoted_dir

  return pushd_cmd
    .. ' '
    .. quoted_dir
    .. ' '
    .. separator
    .. ' '
    .. cmd_with_cwd
    .. ' '
    .. separator
    .. ' '
    .. popd_cmd
end

--- Configure common window options
--- @param win_id number Window ID to configure
--- @param config table Plugin configuration
--- @private
local function configure_window_options(win_id, config)
  if config.window.hide_numbers then
    vim.api.nvim_set_option_value('number', false, {win = win_id})
    vim.api.nvim_set_option_value('relativenumber', false, {win = win_id})
  end

  if config.window.hide_signcolumn then
    vim.api.nvim_set_option_value('signcolumn', 'no', {win = win_id})
  end
end

--- Generate buffer name for instance
--- @param instance_id string Instance identifier
--- @param config table Plugin configuration
--- @return string Buffer name
--- @private
local function generate_buffer_name(instance_id, config)
  if config.git.multi_instance then
    return 'opencode-' .. instance_id:gsub('[^%w%-_]', '-')
  else
    return 'opencode'
  end
end

--- Create a split window according to the specified position configuration
--- @param position string Window position configuration
--- @param config table Plugin configuration containing window settings
--- @param existing_bufnr number|nil Buffer number of existing buffer to show in the split (optional)
--- @private
local function create_split(position, config, existing_bufnr)
  -- Handle floating window
  if position == 'float' then
    return create_float(config, existing_bufnr)
  end

  local is_vertical = position:match('vsplit') or position:match('vertical')

  -- Create the window with the user's specified command
  -- If the command already contains 'split', use it as is
  if position:match('split') then
    vim.cmd(position)
  else
    -- Otherwise append the appropriate split command
    local split_cmd = is_vertical and 'vsplit' or 'split'
    vim.cmd(position .. ' ' .. split_cmd)
  end

  -- If we have an existing buffer to display, switch to it
  if existing_bufnr then
    vim.cmd('buffer ' .. existing_bufnr)
  end

  -- Resize the window appropriately based on split type
  if is_vertical then
    vim.cmd('vertical resize ' .. math.floor(vim.o.columns * config.window.split_ratio))
  else
    vim.cmd('resize ' .. math.floor(vim.o.lines * config.window.split_ratio))
  end
end

--- Set up function to force insert mode when entering the Opencode window
--- @param opencode table The main plugin module
--- @param config table The plugin configuration
function M.force_insert_mode(opencode, config)
  local current_bufnr = vim.fn.bufnr('%')

  -- Check if current buffer is any of our Opencode instances
  local is_opencode_instance = false
  for _, bufnr in pairs(opencode.opencode.instances) do
    if bufnr and bufnr == current_bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      is_opencode_instance = true
      break
    end
  end

  if is_opencode_instance then
    -- Only enter insert mode if we're in the terminal buffer and not already in insert mode
    -- and not configured to stay in normal mode
    if config.window.start_in_normal_mode then
      return
    end

    local mode = vim.api.nvim_get_mode().mode
    if vim.bo.buftype == 'terminal' and mode ~= 't' and mode ~= 'i' then
      vim.cmd 'silent! stopinsert'
      vim.schedule(function()
        vim.cmd 'silent! startinsert'
      end)
    end
  end
end

--- Determine instance ID based on configuration
--- @param config table Plugin configuration
--- @param git table Git module
--- @return string instance_id Instance identifier
--- @private
local function get_instance_id(config, git)
  if config.git.multi_instance then
    if config.git.use_git_root then
      return get_instance_identifier(git)
    else
      return vim.fn.getcwd()
    end
  else
    -- Use a fixed ID for single instance mode
    return 'global'
  end
end

--- Check if buffer is a valid terminal
--- @param bufnr number Buffer number
--- @return boolean is_valid True if buffer is a valid terminal
--- @private
local function is_valid_terminal_buffer(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local buftype = nil
  pcall(function()
    buftype = vim.api.nvim_get_option_value('buftype', {buf = bufnr})
  end)
  
  local terminal_job_id = nil
  pcall(function()
    terminal_job_id = vim.b[bufnr].terminal_job_id
  end)

  return buftype == 'terminal'
    and terminal_job_id
    and vim.fn.jobwait({ terminal_job_id }, 0)[1] == -1
end

--- Open an existing instance buffer in a window
--- @param bufnr number Buffer number
--- @param config table Plugin configuration
--- @private
local function open_instance(bufnr, config)
  if config.window.position == 'float' then
    create_float(config, bufnr)
  else
    create_split(config.window.position, config, bufnr)
  end
  -- Force insert mode more aggressively unless configured to start in normal mode
  if not config.window.start_in_normal_mode then
    vim.schedule(function()
      vim.cmd 'stopinsert | startinsert'
    end)
  end
end

--- Close existing instance windows
--- @param bufnr number Buffer number
--- @private
local function close_instance(bufnr)
  local win_ids = vim.fn.win_findbuf(bufnr)
  for _, win_id in ipairs(win_ids) do
    vim.api.nvim_win_close(win_id, true)
  end
end

--- Create new Opencode instance
--- @param opencode table The main plugin module
--- @param config table Plugin configuration
--- @param git table Git module
--- @param instance_id string Instance identifier
--- @private
local function create_new_instance(opencode, config, git, instance_id)
  if config.window.position == 'float' then
    -- For floating window, create buffer first with terminal
    local new_bufnr = vim.api.nvim_create_buf(false, true) -- unlisted, scratch
    vim.api.nvim_set_option_value('bufhidden', 'hide', {buf = new_bufnr})
    vim.api.nvim_set_option_value('buflisted', false, {buf = new_bufnr})

    -- Create the floating window
    local win_id = create_float(config, new_bufnr)

    -- Set current buffer to run terminal command
    vim.api.nvim_win_set_buf(win_id, new_bufnr)

    -- Determine command
    local cmd = build_command_with_git_root(config, git, config.command)

    -- Run terminal in the buffer
    vim.fn.termopen(cmd)

    -- Create a unique buffer name
    local buffer_name = generate_buffer_name(instance_id, config)
    vim.api.nvim_buf_set_name(new_bufnr, buffer_name)

    -- Configure window options
    configure_window_options(win_id, config)

    -- Store buffer number for this instance
    opencode.opencode.instances[instance_id] = new_bufnr

    -- Enter insert mode if configured
    if config.window.enter_insert and not config.window.start_in_normal_mode then
      vim.cmd 'startinsert'
    end
  else
    -- Regular split window
    create_split(config.window.position, config)

    -- Determine if we should use the git root directory
    local base_cmd = build_command_with_git_root(config, git, config.command)
    local cmd = 'terminal ' .. base_cmd

    vim.cmd(cmd)
    vim.cmd 'setlocal bufhidden=hide'
    vim.cmd 'setlocal nobuflisted'

    -- Create a unique buffer name
    local buffer_name = generate_buffer_name(instance_id, config)
    vim.cmd('file ' .. buffer_name)

    -- Configure window options using helper function
    local current_win = vim.api.nvim_get_current_win()
    configure_window_options(current_win, config)

    -- Store buffer number for this instance
    opencode.opencode.instances[instance_id] = vim.fn.bufnr('%')

    -- Automatically enter insert mode in terminal unless configured to start in normal mode
    if config.window.enter_insert and not config.window.start_in_normal_mode then
      vim.cmd 'startinsert'
    end
  end
end

--- Ensure the Opencode terminal window is open and focused
--- @param opencode table The main plugin module
--- @param config table The plugin configuration
--- @param git table The git module
function M.show(opencode, config, git)
  -- Determine instance ID based on config
  local instance_id = get_instance_id(config, git)
  opencode.opencode.current_instance = instance_id

  -- Check if this Opencode instance is already running
  local bufnr = opencode.opencode.instances[instance_id]

  -- Validate existing buffer
  if bufnr and not is_valid_terminal_buffer(bufnr) then
    opencode.opencode.instances[instance_id] = nil
    bufnr = nil
  end

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local win_ids = vim.fn.win_findbuf(bufnr)
    if #win_ids > 0 then
      -- Already visible, focus the first window
      vim.api.nvim_set_current_win(win_ids[1])
      if not config.window.start_in_normal_mode then
        vim.cmd 'startinsert'
      end
    else
      -- Exists but hidden, open it
      open_instance(bufnr, config)
    end
  else
    -- Create new instance
    create_new_instance(opencode, config, git, instance_id)
  end
end

--- Toggle the Opencode terminal window
--- @param opencode table The main plugin module
--- @param config table The plugin configuration
--- @param git table The git module
function M.toggle(opencode, config, git)
  -- Determine instance ID based on config
  local instance_id = get_instance_id(config, git)
  opencode.opencode.current_instance = instance_id

  -- Check if this Opencode instance is already running
  local bufnr = opencode.opencode.instances[instance_id]

  -- Validate existing buffer
  if bufnr and not is_valid_terminal_buffer(bufnr) then
    -- Buffer is no longer a valid terminal, reset
    opencode.opencode.instances[instance_id] = nil
    bufnr = nil
  end

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local win_ids = vim.fn.win_findbuf(bufnr)
    if #win_ids > 0 then
      -- Opencode is visible, close the window
      close_instance(bufnr)
    else
      -- Opencode buffer exists but is not visible, open it
      open_instance(bufnr, config)
    end
  else
    -- Prune invalid buffer entries
    if bufnr and not vim.api.nvim_buf_is_valid(bufnr) then
      opencode.opencode.instances[instance_id] = nil
    end
    -- Create new instance
    create_new_instance(opencode, config, git, instance_id)
  end
end

--- Restart the Opencode session (delete buffer and start new)
--- @param opencode table The main plugin module
--- @param config table The plugin configuration
--- @param git table The git module
function M.restart(opencode, config, git)
  local instance_id = get_instance_id(config, git)
  local bufnr = opencode.opencode.instances[instance_id]

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    -- Close windows first
    close_instance(bufnr)
    -- Delete buffer
    vim.api.nvim_buf_delete(bufnr, { force = true })
    opencode.opencode.instances[instance_id] = nil
  end

  -- Start new
  M.toggle(opencode, config, git)
end

return M
