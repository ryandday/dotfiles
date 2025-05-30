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
brew install flock

brew install eza        # Modern ls replacement with icons
brew install bat        # Better cat with syntax highlighting  
brew install fd         # Modern find replacement
brew install btop       # Better top/htop replacement
brew install osx-cpu-temp
brew install imagemagick
brew install pkgconfig


# Install global npm packages
npm install -g mcp-hub@latest

# MAC gui instructions

# Move bottom apps to the right side of the screen
defaults write com.apple.dock "orientation" -string "right"
killall Dock

## Remap commands
# Open System Preferences (or System Settings on newer macOS)
# Go to Keyboard → Shortcuts → App Shortcuts
# Click the "+" button to add a new shortcut
# For Menu Title: Enter the exact text from the menu

## Window switching
# Right -- control-cmd l
# Left -- control-cmd h
# Fill -- control-cmd k
# Move to (Right Monitor Name) -- control-cmd s
# Move to (Left Monitor Name) -- control-cmd g

## Disable kitty Close Tab - command-w - I always accidentally press it

## Terminal editing
# cmd-f - forward word
# cmd-f - back word
# ctrl-backspace - delete word
