#!/bin/bash

ln -fs $PWD/zshrc $HOME/.zshrc
ln -fs $PWD/zsh_functions.zsh $HOME/.zsh_functions.zsh
ln -fs $PWD/zsh_plugins.txt $HOME/.zsh_plugins.txt
ln -fs $PWD/tmux.conf $HOME/.tmux.conf
ln -fs $PWD/vimrc $HOME/.vimrc
ln -fs $PWD/alacritty.yml $HOME/.alacritty.yml
# install vim package manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# install tmux plugin manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

