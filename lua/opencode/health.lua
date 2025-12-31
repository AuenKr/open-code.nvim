local M = {}

function M.check()
  vim.health.start("opencode.nvim report")

  -- Check Neovim version
  if vim.fn.has("nvim-0.7.0") == 1 then
    vim.health.ok("Neovim version >= 0.7.0")
  else
    vim.health.error("Neovim version must be >= 0.7.0")
  end

  -- Check external dependencies
  if vim.fn.executable("opencode") == 1 then
    vim.health.ok("opencode installed")
  else
    vim.health.error("opencode not found in PATH. Please install Opencode CLI.")
  end

  if vim.fn.executable("git") == 1 then
    vim.health.ok("git installed")
  else
    vim.health.warn("git not found. Git integration will be disabled.")
  end

  -- Check lua dependencies
  local has_plenary, _ = pcall(require, "plenary")
  if has_plenary then
    vim.health.ok("plenary.nvim installed")
  else
    vim.health.error("plenary.nvim not found. This is a required dependency.")
  end
end

return M
