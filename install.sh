ln -s bash_profile ~/.bash_profile
ln -s tmux.conf ~/.tmux.conf
ln -s vimrc ~/.vimrc
# install vim package manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

