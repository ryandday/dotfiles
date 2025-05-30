-- Plugin configuration using lazy.nvim

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup("plugins", {
  -- Configure lazy.nvim options
  defaults = {
    lazy = false, -- should plugins be lazy-loaded?
    version = false, -- always use the latest git commit
  },
  install = {
    missing = true, -- install missing plugins on startup
    colorscheme = { "gruvbox" }, -- try to load one of these colorschemes when starting an installation during startup
  },
  checker = {
    enabled = true, -- automatically check for plugin updates
    notify = false, -- get a notification when new updates are found
  },
  change_detection = {
    enabled = true, -- automatically check for config file changes and reload the ui
    notify = false, -- get a notification when changes are found
  },
})

-- Manually load bookmark plugin 
-- for some reason it doesn't do my leader b mappings with lazy.nvim
vim.defer_fn(function()
  local ok, bookmark_sets = pcall(require, 'myplugins.bookmark-sets')
  if ok then
    bookmark_sets.setup({
      enable_numbered_jumps = true,
      quick_jump_keys = { "a", "s", "d", "f", "g" }
    })
  end
end, 100)

-- Note: All plugin configurations are now in separate files under lua/plugins/
-- This keeps the main plugin file clean and makes it easy to manage individual plugins 