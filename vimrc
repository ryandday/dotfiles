syntax on
filetype plugin indent on
set nocompatible
inoremap jk <ESC>
set number
set relativenumber

set tabstop=4 " number of visual spaces per TAB
set shiftwidth=4 "spaces used for '>'
set expandtab "insert spaces on tab
set list
set listchars=tab:>~ " Show tab characters as symbols
set cursorline
" set showmatch " highlights matching braces
set encoding=utf-8

" use system clipboard as default copy buffer
set clipboard^=unnamed,unnamedplus
" yank relative path
nnoremap <leader>yf :let @+=expand("%")<CR>
" yank absolute path
nnoremap <leader>ya :let @+=expand("%:p")<CR>
" yank filename
nnoremap <leader>yt :let @+=expand("%:t")<CR>
" yank directory name
nnoremap <leader>yh :let @+=expand("%:p:h")<CR>

" file search
nnoremap <C-p> :find *
set path+=** " adds all files in cwd for find
set wildmenu
set incsearch " when searching, put cursor on next occurrence
set ignorecase " ignore case when searching...
set smartcase " ...unless we type a capital
set wildignore+=**/*.pyc*/**
set wildignore+=**/*pycache*/**

" search recursively in working directory for current word under cursor and open quickfix
command! VIMGREP :execute 'vimgrep '.expand('<cword>').' **/*' | :copen
nnoremap <Leader>g :VIMGREP<CR>

" set up nice recursive search
nnoremap <Leader>f :vimgrep  **/* <Left><Left><Left><Left><Left><Left>
nnoremap <Leader>c :copen<CR>

" backups
set undofile
set backup
" set cached vim stuff in its own directory
set undodir=~/.vim/.undo//
set backupdir=~/.vim/.backup//
set directory=~/.vim/.swp//

set hidden " enable changing buffers without saving
set lazyredraw

" netrw settings
let g:netrw_banner=0
" let g:netrw_liststyle=3 " tree view
let g:netrw_bufsettings = 'noma nomod nu nobl nowrap ro' " Set line numbers in netrw
nnoremap - :E<CR>
nnoremap <Leader>e :E<CR>
nnoremap <Leader>E :E .<CR>

" disable modelines, bc its a possible security risk
set modelines=0
set nomodeline

" leader shortcuts
let mapleader = "\<Space>"
" Prevent leader key from inserting a space 
nnoremap <SPACE> <Nop> 
" save and quit
nnoremap <Leader>s :w<CR>
nnoremap <Leader>q :q<CR>
" vim splits 
nnoremap <Leader>j <C-w>j 
nnoremap <Leader>k <C-w>k 
nnoremap <Leader>l <C-w>l 
nnoremap <Leader>h <C-w>h 
set splitbelow
set splitright

nnoremap <Leader>z :source ~/.vimrc<CR> 

" Buffer commands
nnoremap <Leader>b :b 
nnoremap <Leader>n :bn<CR>
nnoremap <Leader>p :bp<CR>
nnoremap <Leader>d :bd

" Toggle relative line numbering
nnoremap <Leader>r :set norelativenumber!<CR>
"
" plugins/things to add:
" gutentags or tag generating git hooks
" tagbar
" git support
" Debugging support (if not on vim 8)
" fzf
" ripgrep or silver searcher
" Async linting
" Smarter async autocomplete
