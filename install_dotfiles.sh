#!/bin/bash

ln -fs $PWD/zshrc $HOME/.zshrc
ln -fs $PWD/zsh_functions.zsh $HOME/.zsh_functions.zsh
ln -fs $PWD/zsh_plugins.txt $HOME/.zsh_plugins.txt
ln -fs $PWD/tmux.conf $HOME/.tmux.conf
ln -fs $PWD/vimrc $HOME/.vimrc
mkdir -p $HOME/.config/kitty
ln -fs $PWD/kitty.conf $HOME/.config/kitty/kitty.conf
# install kitty theme
curl -L -o ~/.config/kitty/gruvbox_dark.conf https://github.com/wdomitrz/kitty_gruvbox_theme/raw/master/gruvbox_dark.conf
# install vim package manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# install tmux plugin manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
mkdir -p ~/.vim/undo
mkdir -p ~/.vim/undonvim
mkdir -p ~/.vim/backup
mkdir -p ~/.vim/swp

