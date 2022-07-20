#!/bin/bash

ln -s $PWD/bashrc $HOME/.bashrc
ln -s $PWD/tmux.conf $HOME/.tmux.conf
ln -s $PWD/vimrc $HOME/.vimrc
# install vim package manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# install tmux plugin manager
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

