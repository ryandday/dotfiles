#!/bin/bash

# Update package lists
sudo apt-get update --fix-missing

# Install main packages
sudo apt install zsh fzf ripgrep zsh-antidote lf kitty ccls plocate build-essential llvm clang-format clangd sccache xclip luarocks bat fd-find

# Modern CLI tools that might need special installation
# btop (if not available via apt, install from snap or build from source)
if ! command -v btop &> /dev/null; then
    if command -v snap &> /dev/null; then
        sudo snap install btop
    else
        echo "⚠️  btop not available via apt or snap. Install manually from: https://github.com/aristocratos/btop"
    fi
fi

# eza (install from GitHub releases since it's not in most repos yet)
if ! command -v eza &> /dev/null; then
    echo "Installing eza (modern ls replacement)..."
    EZA_VERSION=$(curl -s https://api.github.com/repos/eza-community/eza/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    wget -O /tmp/eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
    sudo tar -xzf /tmp/eza.tar.gz -C /usr/local/bin/
    rm /tmp/eza.tar.gz
fi

# Change default shell to zsh
chsh -s $(which zsh)
