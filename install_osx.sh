#!/bin/bash

# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install packages
brew install vim
brew install tmux
brew install fzf
brew install rg
brew install antidote
brew install lf
brew install kitty
brew install ccls
brew install xclip
brew install luarocks
brew install node

# Modern CLI tools
brew install eza        # Modern ls replacement with icons
brew install bat        # Better cat with syntax highlighting  
brew install fd         # Modern find replacement
brew install btop       # Better top/htop replacement
brew install osx-cpu-temp

# Install global npm packages
npm install -g mcp-hub@latest