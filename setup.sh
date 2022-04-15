cp bash_profile ~/.bash_profile
cp tmux.conf ~/.tmux.conf
cp vimrc ~/.vimrc
mkdir ~/.vim
# install vim package manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

