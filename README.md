# Opencode Neovim Plugin

[![GitHub License](https://img.shields.io/github/license/AuenKr/open-code.nvim?style=flat-square)](https://github.com/AuenKr/open-code.nvim/blob/main/LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/AuenKr/open-code.nvim?style=flat-square)](https://github.com/AuenKr/open-code.nvim/stargazers)
[![GitHub Issues](https://img.shields.io/github/issues/AuenKr/open-code.nvim?style=flat-square)](https://github.com/AuenKr/open-code.nvim/issues)
[![CI](https://img.shields.io/github/actions/workflow/status/AuenKr/open-code.nvim/ci.yml?branch=main&style=flat-square&logo=github)](https://github.com/AuenKr/open-code.nvim/actions/workflows/ci.yml)
[![Neovim Version](https://img.shields.io/badge/Neovim-0.7%2B-blueviolet?style=flat-square&logo=neovim)](https://github.com/neovim/neovim)
[![Tests](https://img.shields.io/badge/Tests-44%20passing-success?style=flat-square&logo=github-actions)](https://github.com/AuenKr/open-code.nvim/actions/workflows/ci.yml)
[![Version](https://img.shields.io/badge/Version-0.4.2-blue?style=flat-square)](https://github.com/AuenKr/open-code.nvim/releases/tag/v0.4.2)
[![Discussions](https://img.shields.io/github/discussions/AuenKr/open-code.nvim?style=flat-square&logo=github)](https://github.com/AuenKr/open-code.nvim/discussions)

*A seamless integration between [Opencode](https://github.com/anthropics/opencode) AI assistant and Neovim*

[Features](#features) •
[Requirements](#requirements) •
[Installation](#installation) •
[Configuration](#configuration) •
[Usage](#usage) •
[Contributing](#contributing) •
[Discussions](https://github.com/AuenKr/open-code.nvim/discussions)

![Opencode in Neovim](https://github.com/AuenKr/open-code.nvim/blob/main/assets/opencode.png?raw=true)

This plugin was built entirely with Opencode in a Neovim terminal, and then inside itself using Opencode for everything!

## Features

- 🚀 Toggle Opencode in a terminal window with a single key press
- 🧠 Support for command-line arguments like `--continue` and custom variants
- 🔄 Automatically detect and reload files modified by Opencode
- ⚡ Real-time buffer updates when files are changed externally
- 📱 Customizable window position and size (including floating windows)
- 🤖 Integration with which-key (if available)
- 📂 Automatically uses git project root as working directory (when available)
- 🧩 Modular and maintainable code structure
- 📋 Type annotations with LuaCATS for better IDE support
- ✅ Configuration validation to prevent errors
- 🧪 Testing framework for reliability (44 comprehensive tests)

## Requirements

- Neovim 0.7.0 or later
- [Opencode CLI](https://github.com/anthropics/opencode) tool installed and available in your PATH
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (dependency for git operations)

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  "AuenKr/open-code.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for git operations
  },
  config = function()
    require("opencode").setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'AuenKr/open-code.nvim',
  requires = {
    'nvim-lua/plenary.nvim', -- Required for git operations
  },
  config = function()
    require('opencode').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'nvim-lua/plenary.nvim'
Plug 'AuenKr/open-code.nvim'
" After installing, add this to your init.vim:
" lua require('opencode').setup()
```

## Configuration

The plugin can be configured by passing a table to the `setup` function. Here's the default configuration:

```lua
require("opencode").setup({
  -- Terminal window settings
  window = {
    split_ratio = 0.3,      -- Percentage of screen for the terminal window (height for horizontal, width for vertical splits)
    position = "botright",  -- Position of the window: "botright", "topleft", "vertical", "float", etc.
    enter_insert = true,    -- Whether to enter insert mode when opening Opencode
    hide_numbers = true,    -- Hide line numbers in the terminal window
    hide_signcolumn = true, -- Hide the sign column in the terminal window
    
    -- Floating window configuration (only applies when position = "float")
    float = {
      width = "80%",        -- Width: number of columns or percentage string
      height = "80%",       -- Height: number of rows or percentage string
      row = "center",       -- Row position: number, "center", or percentage string
      col = "center",       -- Column position: number, "center", or percentage string
      relative = "editor",  -- Relative to: "editor" or "cursor"
      border = "rounded",   -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
    },
  },
  -- File refresh settings
  refresh = {
    enable = true,           -- Enable file change detection
    updatetime = 100,        -- updatetime when Opencode is active (milliseconds)
    timer_interval = 1000,   -- How often to check for file changes (milliseconds)
    show_notifications = true, -- Show notification when files are reloaded
  },
  -- Git project settings
  git = {
    use_git_root = true,     -- Set CWD to git root when opening Opencode (if in git project)
  },
  -- Shell-specific settings
  shell = {
    separator = '&&',        -- Command separator used in shell commands
    pushd_cmd = 'pushd',     -- Command to push directory onto stack (e.g., 'pushd' for bash/zsh, 'enter' for nushell)
    popd_cmd = 'popd',       -- Command to pop directory from stack (e.g., 'popd' for bash/zsh, 'exit' for nushell)
  },
  -- Command settings
  command = "opencode",        -- Command used to launch Opencode
  -- Command variants
  command_variants = {
    -- Conversation management
    continue = "--continue", -- Resume the most recent conversation
    resume = "--resume",     -- Display an interactive conversation picker

    -- Output options
    verbose = "--verbose",   -- Enable verbose logging with full turn-by-turn output
  },
  -- Keymaps
  keymaps = {
    toggle = {
      normal = "<C-,>",       -- Normal mode keymap for toggling Opencode, false to disable
      terminal = "<C-,>",     -- Terminal mode keymap for toggling Opencode, false to disable
      variants = {
        continue = "<leader>cC", -- Normal mode keymap for Opencode with continue flag
        verbose = "<leader>cV",  -- Normal mode keymap for Opencode with verbose flag
      },
    },
    window_navigation = true, -- Enable window navigation keymaps (<C-h/j/k/l>)
    scrolling = true,         -- Enable scrolling keymaps (<C-f/b>) for page up/down
  }
})
```

## Usage

### Quick Start

```vim
" In your Vim/Neovim commands or init file:
:Opencode
```

```lua
-- Or from Lua:
vim.cmd[[Opencode]]

-- Or map to a key:
vim.keymap.set('n', '<leader>cc', '<cmd>Opencode<CR>', { desc = 'Toggle Opencode' })
```

### Commands

Basic command:

- `:Opencode` - Toggle the Opencode terminal window

Conversation management commands:

- `:OpencodeContinue` - Resume the most recent conversation
- `:OpencodeResume` - Display an interactive conversation picker

Output options command:

- `:OpencodeVerbose` - Enable verbose logging with full turn-by-turn output

Note: Commands are automatically generated for each entry in your `command_variants` configuration.

### Key Mappings

Default key mappings:

- `<leader>ac` - Toggle Opencode terminal window (normal mode)
- `<C-o>` - Toggle Opencode terminal window (terminal mode)

Variant mode mappings (if configured):

- `<leader>aC` - Toggle Opencode with --continue flag
- `<leader>aV` - Toggle Opencode with --verbose flag

Additionally, when in the Opencode terminal:

- `<C-h>` - Move to the window on the left
- `<C-j>` - Move to the window below
- `<C-k>` - Move to the window above
- `<C-l>` - Move to the window on the right
- `<C-f>` - Scroll full-page down
- `<C-b>` - Scroll full-page up

Note: After scrolling with `<C-f>` or `<C-b>`, you'll need to press the `i` key to re-enter insert mode so you can continue typing to Opencode.

When Opencode modifies files that are open in Neovim, they'll be automatically reloaded.

### Floating Window Example

To use Opencode in a floating window:

```lua
require("opencode").setup({
  window = {
    position = "float",
    float = {
      width = "90%",      -- Take up 90% of the editor width
      height = "90%",     -- Take up 90% of the editor height
      row = "center",     -- Center vertically
      col = "center",     -- Center horizontally
      relative = "editor",
      border = "double",  -- Use double border style
    },
  },
})
```

## How it Works

This plugin:

1. Creates a terminal buffer running the Opencode CLI
2. Sets up autocommands to detect file changes on disk
3. Automatically reloads files when they're modified by Opencode
4. Provides convenient keymaps and commands for toggling the terminal
5. Automatically detects git repositories and sets working directory to the git root

## Contributing

Contributions are welcome! Please check out our [contribution guidelines](CONTRIBUTING.md) for details on how to get started.

## License

MIT License - See [LICENSE](LICENSE) for more information.

## Development

For a complete guide on setting up a development environment, installing all required tools, and understanding the project structure, please refer to [DEVELOPMENT.md](DEVELOPMENT.md).

### Development Setup

The project includes comprehensive setup for development:

- Complete installation instructions for all platforms in [DEVELOPMENT.md](DEVELOPMENT.md)
- Pre-commit hooks for code quality
- Testing framework with 44 comprehensive tests
- Linting and formatting tools
- Weekly dependency updates workflow for Opencode CLI and actions

```bash
# Run tests
make test

# Check code quality
make lint

# Set up pre-commit hooks
scripts/setup-hooks.sh

# Format code
make format
```

## Troubleshooting

If you encounter issues, you can run the following command in Neovim to verify your installation and dependencies:

```vim
:checkhealth opencode
```

This will check for:
- Neovim version requirements
- Opencode CLI installation
- Required dependencies (plenary.nvim)

## Community

- [GitHub Discussions](https://github.com/AuenKr/open-code.nvim/discussions) - Get help, share ideas, and connect with other users
- [GitHub Issues](https://github.com/AuenKr/open-code.nvim/issues) - Report bugs or suggest features
- [GitHub Pull Requests](https://github.com/AuenKr/open-code.nvim/pulls) - Contribute to the project

## Acknowledgements

- [Opencode](https://github.com/anthropics/opencode) by Anthropic - This plugin was entirely built using Opencode. Development cost: 25% used $18.91 spent
- [Plenary.nvim](https://github.com/nvim-lua/plenary.nvim) - Core dependency for testing framework and Git operations
- [Semantic Versioning](https://semver.org/) - Versioning standard used in this project
- [Contributor Covenant](https://www.contributor-covenant.org/) - Code of Conduct standard
- [Keep a Changelog](https://keepachangelog.com/) - Changelog format
- [LuaCATS](https://luals.github.io/wiki/annotations/) - Type annotations for better IDE support
- [StyLua](https://github.com/JohnnyMorganz/StyLua) - Lua code formatter
- [Luacheck](https://github.com/lunarmodules/luacheck) - Lua static analyzer and linter

---

Made with ❤️ by [Golden Kumar](https://github.com/AuenKr)
