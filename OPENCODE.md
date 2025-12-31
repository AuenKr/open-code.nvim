# Project: OpenCode Plugin

## Overview

OpenCode Plugin provides seamless integration between the OpenCode AI assistant and Neovim. It enables direct communication with the OpenCode CLI from within the editor, context-aware interactions, and various utilities to enhance AI-assisted development within Neovim.

## Essential Commands

- Run Tests: `make test`
- Check Formatting: `make lint`
- Format Code: `make format`
- Run Linter: `make lint`
- Build Documentation: `make docs`

## Project Structure

- `/lua/opencode`: Main plugin code
- `/lua/opencode/cli`: OpenCode CLI integration
- `/lua/opencode/ui`: UI components for interactions
- `/lua/opencode/context`: Context management utilities
- `/after/plugin`: Plugin setup and initialization
- `/tests`: Test files for plugin functionality
- `/doc`: Vim help documentation

## Current Focus

- Integrating nvim-toolkit for shared utilities
- Adding hooks-util as git submodule for development workflow
- Enhancing bidirectional communication with OpenCode CLI
- Implementing better context synchronization
- Adding buffer-specific context management

## Multi-Instance Support

The plugin supports running multiple OpenCode instances, one per git repository root:

- Each git repository maintains its own OpenCode instance
- Works across multiple Neovim tabs with different projects
- Allows working on multiple projects in parallel
- Configurable via `git.multi_instance` option (defaults to `true`)
- Instances remain in their own directory context when switching between tabs
- Buffer names include the git root path for easy identification

Example configuration to disable multi-instance mode:

```lua
require('opencode').setup({
  git = {
    multi_instance = false  -- Use a single global OpenCode instance
  }
})
```

## Documentation Links

- Tasks: `docs/tasks/opencode-tasks.md`
- Project Status: `docs/project-status.md`
