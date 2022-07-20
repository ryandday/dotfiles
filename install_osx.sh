#!/bin/bash

# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# install packages
brew install vim
brew install tmux
brew install fzf
brew install rg
brew install --cask alacritty # System Preferences - Security and Privacy - General - Open Anyway
