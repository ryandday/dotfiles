#!/bin/bash

ln -fs $PWD/zshrc $HOME/.zshrc
ln -fs $PWD/zsh_functions.zsh $HOME/.zsh_functions.zsh
ln -fs $PWD/zsh_plugins.txt $HOME/.zsh_plugins.txt
ln -fs $PWD/tmux.conf $HOME/.tmux.conf
ln -fs $PWD/vimrc $HOME/.vimrc
ln -fs $PWD/alacritty.toml $HOME/.alacritty.toml
# install vim package manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# install tmux plugin manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
mkdir -p ~/.vim/undo
mkdir -p ~/.vim/undonvim
mkdir -p ~/.vim/backup
mkdir -p ~/.vim/swp

