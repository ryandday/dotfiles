# Plugin Configuration

This directory contains plugin specifications for lazy.nvim. Each file represents a logical grouping of related plugins.

## File Organization

- **`ai.lua`** - AI assistance plugins (Copilot, Avante)
- **`colorscheme.lua`** - Color scheme and theming
- **`completion.lua`** - Autocompletion and snippets (nvim-cmp, LuaSnip)
- **`debugging.lua`** - Debugging tools (termdbg)
- **`diagnostics.lua`** - Enhanced diagnostics (Trouble)
- **`editing.lua`** - Text editing enhancements (surround, commentary, etc.)
- **`explorer.lua`** - File exploration (NERDTree, web-devicons)
- **`git.lua`** - Git integration (fugitive, gitgutter, flog)
- **`lsp.lua`** - LSP configuration (Mason, lspconfig, null-ls)
- **`telescope.lua`** - Fuzzy finding (Telescope, FZF)
- **`treesitter.lua`** - Syntax highlighting and parsing

## Lazy Loading

Plugins are configured with appropriate lazy loading strategies:

- **Event-based**: Load on specific events (BufReadPre, InsertEnter, etc.)
- **Command-based**: Load when specific commands are executed
- **Key-based**: Load when specific key mappings are used
- **Filetype-based**: Load for specific file types

## Adding New Plugins

To add a new plugin:

1. Choose the appropriate file based on the plugin's purpose
2. Add the plugin specification following lazy.nvim format
3. Configure appropriate lazy loading if possible
4. Add any necessary setup/configuration in the `config` function

## Plugin Management

- **Install**: Plugins auto-install on first startup
- **Update**: `:Lazy update` to update all plugins
- **Clean**: `:Lazy clean` to remove unused plugins
- **Profile**: `:Lazy profile` to see loading times
- **UI**: `:Lazy` to open the management interface 