#!/bin/bash


ln -fs $PWD/zshrc $HOME/.zshrc
ln -fs $PWD/zsh_functions.zsh $HOME/.zsh_functions.zsh
ln -fs $PWD/zsh_plugins.txt $HOME/.zsh_plugins.txt
ln -fs $PWD/tmux.conf $HOME/.tmux.conf
# Create ~/.config directory if it doesn't exist
mkdir -p $HOME/.config
# Remove existing nvim config and symlink the new folder structure
rm -rf $HOME/.config/nvim
ln -fs $PWD/nvim $HOME/.config/nvim
mkdir -p $HOME/.config/kitty
ln -fs $PWD/kitty.conf $HOME/.config/kitty/kitty.conf
# install kitty theme
curl -L -o ~/.config/kitty/gruvbox_dark.conf https://github.com/wdomitrz/kitty_gruvbox_theme/raw/master/gruvbox_dark.conf
# install tmux plugin manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
mkdir -p ~/.vim/.undo
mkdir -p ~/.vim/.undonvim
mkdir -p ~/.vim/.backup
mkdir -p ~/.vim/.swp

# Setup git configuration
echo "Setting up git configuration..."
read -p "Enter your git user name: " GIT_USER_NAME
read -p "Enter your git email: " GIT_USER_EMAIL

# Set git user name and email globally (stored outside this repo)
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

# Setup git config include to use our dotfiles config
# This way git can write to ~/.gitconfig without affecting our repo
git config --global include.path "$PWD/gitconfig"
echo "Git configuration included from dotfiles with name: $GIT_USER_NAME, email: $GIT_USER_EMAIL"

