# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup and Installation

This dotfiles repository supports both macOS and Ubuntu systems. Install using:

```bash
# macOS setup (installs Homebrew packages)
./install_osx.sh

# Install dotfiles (creates symlinks to home directory)
./install_dotfiles.sh
```

The installation creates symlinks for:
- Shell configuration: `zshrc`, `zsh_functions.zsh`, `zsh_plugins.txt`
- Terminal multiplexer: `tmux.conf`
- Editor configuration: `nvim/` → `~/.config/nvim`
- Terminal emulator: `kitty.conf` → `~/.config/kitty/kitty.conf`
- Git configuration: `gitconfig` (included via `git config --global include.path`)

## Key Components

### Zsh Configuration
- **Main config**: `zshrc` - Enhanced prompt with git integration, performance optimizations
- **Functions**: `zsh_functions.zsh` - Custom functions for tmux, git, networking, system monitoring, AWS debugging
- **Plugin management**: Uses antidote plugin manager with plugins listed in `zsh_plugins.txt`

### Neovim Configuration
- **Entry point**: `nvim/init.lua` loads modular configuration from `lua/config/`
- **Plugin system**: Uses lazy.nvim for plugin management
- **Custom plugins**: `lua/myplugins/` contains custom functionality
- **Third-party**: `third_party/termdbg/` for terminal debugging support

### Tmux Configuration
- **Prefix**: `C-Space` (Ctrl+Space)
- **Key bindings**: Vim-style navigation (hjkl)
- **Project switching**: `C-l` opens fzf project switcher
- **Session switching**: `C-j` opens fzf session switcher
- **Plugins**: Uses tpm with resurrect, continuum, cpu, battery plugins

## Development Workflow Features

### Git Integration
- Git status indicators in prompt with background caching for performance
- Git aliases: `gb` (branch switching with fzf), `gbr` (remote branch checkout)
- Enhanced git functions: `gst()` (short status), `glog()` (graph log)

### Project Management
- `ta()` function: Fuzzy find projects in `~/repos`, create/switch tmux sessions
- Automatic tmux attachment on shell startup (except in VSCode)
- Project-aware git status caching

### System Monitoring
- Network debugging functions: `port()`, `killport()`, `tcptest()`, `httptest()`, `ssltest()`
- Memory/CPU monitoring: `memproc()`, `cpuproc()`, `syssum()`, `perfsnap()`
- Performance benchmarking: `prompt_benchmark()` for shell prompt optimization

### AWS Development
- `aws_get_stack_info()`: Comprehensive ECS stack debugging with filtering options
- `aws_stack_events()`: CloudFormation stack event monitoring
- Generates AWS console URLs for easy navigation

## Performance Considerations

The shell configuration is optimized for large repositories:
- Git status uses background caching to avoid blocking the prompt
- FZF configured with ripgrep for fast file searching
- VCS info configured to skip expensive operations
- Prompt components benchmarked for performance

## Tool Dependencies

Required tools installed by `install_osx.sh`:
- Core: `neovim`, `tmux`, `fzf`, `ripgrep`, `antidote`
- Modern replacements: `eza` (ls), `bat` (cat), `btop` (top)
- Development: `node`, `luarocks`, `ccls`
- System: `kitty`, `imagemagick`
