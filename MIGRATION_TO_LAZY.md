# Migration to Lazy.nvim

This document outlines the migration from vim-plug to lazy.nvim for better plugin management and performance.

## What Changed

### Plugin Manager
- **Before**: vim-plug
- **After**: lazy.nvim

### Benefits of lazy.nvim
- **Lazy loading**: Plugins load only when needed, improving startup time
- **Better UI**: Modern interface for managing plugins
- **Built-in profiling**: Easy to see which plugins affect startup time
- **Better dependency management**: Automatic handling of plugin dependencies
- **Lockfile support**: Ensures consistent plugin versions

### File Structure
```
nvim/lua/plugins/
├── ai.lua           # AI assistance (Copilot, Avante)
├── colorscheme.lua  # Gruvbox theme
├── completion.lua   # nvim-cmp, LuaSnip
├── debugging.lua    # termdbg
├── diagnostics.lua  # Trouble
├── editing.lua      # Surround, commentary, etc.
├── explorer.lua     # NERDTree, web-devicons
├── git.lua          # Fugitive, gitgutter, flog
├── lsp.lua          # Mason, lspconfig
├── telescope.lua    # Telescope, FZF
└── treesitter.lua   # Treesitter, syntax
```

## Migration Steps

### 1. Automatic Installation
- lazy.nvim auto-bootstraps itself (no manual installation needed)
- All plugins auto-install on first Neovim startup

### 2. Removed vim-plug Dependencies
- No more `:PlugInstall` commands needed
- vim-plug installation removed from `install_dotfiles.sh`

### 3. Updated Commands
| vim-plug | lazy.nvim |
|----------|-----------|
| `:PlugInstall` | `:Lazy install` |
| `:PlugUpdate` | `:Lazy update` |
| `:PlugClean` | `:Lazy clean` |
| `:PlugStatus` | `:Lazy` |

### 4. Performance Improvements
- Plugins now lazy load based on:
  - File types (e.g., C++ plugins only load for .cpp files)
  - Commands (e.g., Git plugins load when using Git commands)
  - Events (e.g., LSP loads when opening files)
  - Key mappings (e.g., Telescope loads when using search keys)

## Key Features

### Lazy Loading Examples
- **Treesitter**: Loads on `BufReadPost` and `BufNewFile`
- **LSP**: Loads on file read/creation events
- **Git plugins**: Load when Git commands are used
- **Completion**: Loads on `InsertEnter`
- **AI plugins**: Load on `VeryLazy` for minimal startup impact

### Plugin Organization
Each plugin file returns a table of plugin specifications:
```lua
return {
  {
    "plugin/name",
    event = "BufReadPre",  -- When to load
    config = function()    -- How to configure
      -- setup code here
    end,
  },
}
```

## Verification

After migration, verify everything works:

1. **Open Neovim**: `nvim`
2. **Check plugin status**: `:Lazy`
3. **Verify features**:
   - LSP: Open a C++ file, check if clangd works
   - Completion: Enter insert mode, test Tab completion
   - Git: Use `<leader>gs` for git status
   - Search: Use `<leader>ff` for file search
   - AI: Test Avante or Copilot features

## Troubleshooting

- **Plugin not loading**: Check `:Lazy` for any errors
- **Slow startup**: Run `:Lazy profile` to see loading times
- **Missing features**: Ensure the plugin loaded with `:Lazy`

## Rollback (if needed)

If you need to rollback to vim-plug:
1. Restore the original `vimrc` file
2. Re-add vim-plug installation to `install_dotfiles.sh`
3. Run `:PlugInstall` after restarting Neovim 