#!/bin/bash

ln -s $PWD/zshrc $HOME/.zshrc
ln -s $PWD/zsh_plugins.txt $HOME/.zsh_plugins.txt
ln -s $PWD/tmux.conf $HOME/.tmux.conf
ln -s $PWD/vimrc $HOME/.vimrc
ln -s $PWD/alacritty.yml $HOME/.alacritty.yml
# install vim package manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# install tmux plugin manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

