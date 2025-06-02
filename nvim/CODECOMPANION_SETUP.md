# CodeCompanion.nvim Setup Guide

This guide explains how to configure CodeCompanion.nvim as a replacement for Avante.

## Features

- **Multiple AI Providers**: Anthropic (Claude), OpenAI, Gemini, Copilot, and more
- **Chat Interface**: Similar to Avante but with better performance
- **Inline Code Editing**: Direct code modifications
- **Agent Workflows**: Advanced automation capabilities
- **Better Integration**: Works seamlessly with existing Neovim plugins

## Environment Setup

Create environment variables to configure your preferred AI provider:

### Option 1: Anthropic Claude (Recommended)
```bash
# Add to your ~/.zshrc or ~/.bashrc
export CODECOMPANION_PROVIDER="anthropic"
export ANTHROPIC_API_KEY="your-api-key-here"
```

### Option 2: OpenAI
```bash
export CODECOMPANION_PROVIDER="openai" 
export OPENAI_API_KEY="your-api-key-here"
```

### Option 3: Google Gemini
```bash
export CODECOMPANION_PROVIDER="gemini"
export GEMINI_API_KEY="your-api-key-here"
```

### Option 4: GitHub Copilot
```bash
export CODECOMPANION_PROVIDER="copilot"
# No API key needed - uses your existing Copilot subscription
```

## Key Bindings

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ac` | Normal/Visual | Open action palette |
| `<leader>aa` | Normal/Visual | Toggle chat window |
| `<leader>ad` | Visual | Add selection to chat |

### Mnemonic Helper
- `<leader>a` + `a` = **A**ctivate chat
- `<leader>a` + `c` = **C**ommands/actions  
- `<leader>a` + `d` = a**D**d to chat

## Commands

### Core Commands
- `:CodeCompanion` - Open the inline assistant
- `:CodeCompanionChat` - Open a chat buffer
- `:CodeCompanionCmd` - Generate a command in the command-line
- `:CodeCompanionActions` - Open the Action Palette

### Advanced Usage
- `:CodeCompanion <prompt>` - Prompt the inline assistant
- `:CodeCompanion <adapter> <prompt>` - Prompt with a specific adapter
- `:CodeCompanion /<prompt>` - Call a prompt from the library
- `:CodeCompanionChat <prompt>` - Send a prompt to the LLM via chat
- `:CodeCompanionChat <adapter>` - Open chat with a specific adapter
- `:CodeCompanionChat Toggle` - Toggle a chat buffer
- `:CodeCompanionChat Add` - Add visually selected text to current chat

### Telescope Integration
- `:Telescope codecompanion` - Open CodeCompanion via Telescope

## Usage Examples

### 1. Quick Chat
1. Press `<leader>aa` to open chat
2. Type your question and press Enter
3. Get AI-powered responses with code suggestions

### 2. Code Refactoring
1. Select code in visual mode
2. Press `<leader>ad` to add to chat
3. Ask for refactoring suggestions
4. Apply changes directly to your code

### 3. Inline Editing
1. Press `<leader>ac` to open action palette
2. Choose "Inline Assistant"
3. Describe what you want to change
4. CodeCompanion will modify the code directly

### 4. Code Explanation
1. Select complex code
2. Press `<leader>ac` for actions
3. Choose "Explain Code"
4. Get detailed explanations

## Variables, Slash Commands & Tools

### Variables (accessed with `#`)
- `#buffer` - Shares current buffer's code
- `#lsp` - Shares LSP information and diagnostics
- `#viewport` - Shares what you see on screen

### Slash Commands (accessed with `/`)
- `/buffer` - Insert open buffers
- `/fetch` - Insert URL contents
- `/file` - Insert a file
- `/help` - Insert content from help tags
- `/now` - Insert current date and time
- `/symbols` - Insert symbols from a selected file
- `/terminal` - Insert terminal output
- `/image` - Add images to chat
- `/workspace` - Share defined groups of files/symbols

### Tools/Agents (accessed with `@`)
- `@cmd_runner` - Run shell commands (subject to approval)
- `@editor` - Edit code in Neovim buffers
- `@files` - Work with files on filesystem (subject to approval)
- `@web_search` - Search the web for information
- `@full_stack_dev` - Combined agent with all tools

## Built-in Prompts

The following prompts are available via `:CodeCompanion /<prompt>` or the action palette:

- `/commit` - Generate a commit message
- `/explain` - Explain how selected code works
- `/fix` - Fix the selected code
- `/lsp` - Explain LSP diagnostics for selected code
- `/tests` - Generate unit tests for selected code

## Advantages over Avante

1. **Better Performance**: Async operations, faster responses
2. **More Providers**: Support for multiple AI services
3. **Better UI**: Improved chat interface and action palette
4. **Agent Workflows**: Advanced automation capabilities
5. **Better Integration**: Works with existing Neovim ecosystem
6. **Active Development**: Regular updates and improvements

## Troubleshooting

### Check Health
```vim
:checkhealth codecompanion
```

### Enable Debug Logging
Change `log_level = "ERROR"` to `log_level = "DEBUG"` in the config.

### Common Issues

1. **No API Key**: Make sure environment variables are set correctly
2. **Provider Not Working**: Check if the provider is properly configured
3. **Keybinding Conflicts**: Adjust keymaps in the configuration if needed

## Migration from Avante

1. The configuration automatically replaces Avante
2. Update your environment variables from `AVANTE_PROVIDER` to `CODECOMPANION_PROVIDER`
3. Remove any Avante-specific settings from your shell profile
4. Restart Neovim and run `:Lazy sync` to update plugins

## Additional Resources

- [Official Documentation](https://codecompanion.olimorris.dev)
- [GitHub Repository](https://github.com/olimorris/codecompanion.nvim)
- [Issue Tracker](https://github.com/olimorris/codecompanion.nvim/issues) 