syntax on
filetype plugin indent on
set tabstop=4 " number of visual spaces per TAB
set shiftwidth=4 "using '>' uses 4 spaces
set expandtab "insert 4 spaces on tab
set listchars=tab:>~ " Show tab characters as symbols
set list
inoremap jk <ESC>
set cursorline
" set showmatch " highlights matching braces
set encoding=utf-8
" Use system clipboard as default copy buffer
" Copy current filename into default buffer
" Use different functions in different operating systems for copying
if system('uname -s') == "Darwin\n"
  set clipboard=unnamed "OSX
  nnoremap <Leader>y :let @+=expand("%:p")<CR>
else
  set clipboard=unnamedplus "Linux
  nnoremap <Leader>y :let @+=expand("%")<CR>
endif

set number
set relativenumber
" file search
nnoremap <C-p> :find *
set path+=** " adds all files in cwd for find
set wildmenu
set incsearch " when searching, put cursor on next occurrence
set ignorecase " Ignore case when searching...
set smartcase " ...unless we type a capital
set wildignore+=**/*.pyc*/**
set wildignore+=**/*pycache*/**

set undofile
set backup
"Set cached vim stuff in its own directory
set undodir=~/.vim/.undo//
set backupdir=~/.vim/.backup//
set directory=~/.vim/.swp//

" highlight column if the width is too long
" highlight ColorColumn ctermbg=magenta
" call matchadd('ColorColumn', '\%81v', 100)

set hidden " enable changing buffers without saving
set lazyredraw

" netrw settings
let g:netrw_banner=0
" let g:netrw_liststyle=3 " tree view
let g:netrw_bufsettings = 'noma nomod nu nobl nowrap ro' " Set line numbers in netrw

" Disable modelines, bc its a possible security risk
set modelines=0
set nomodeline

"Leader shortcuts
let mapleader = "\<Space>"
" Prevent leader key from inserting a space 
nnoremap <SPACE> <Nop> 
" Save and quit
nnoremap <Leader>s :w<CR>
nnoremap <Leader>q :q<CR>
" Netrw
nnoremap <Leader>e :E<CR>
nnoremap <Leader>E :E .<CR>
" Navigate vim windows
nnoremap <Leader>j <C-w>j 
nnoremap <Leader>k <C-w>k 
nnoremap <Leader>l <C-w>l 
nnoremap <Leader>h <C-w>h 

nnoremap <Leader>z :source ~/.vimrc<CR> 

" Search recursively in working directory for current word under cursor and open quickfix
command VIMGREP :execute 'vimgrep '.expand('<cword>').' **/*' | :copen
nnoremap <Leader>g :VIMGREP<CR>

" Set up nice recursive search
nnoremap <Leader>f :vimgrep  **/* <Left><Left><Left><Left><Left><Left>
nnoremap <Leader>c :copen<CR>
" Buffer commands
nnoremap <Leader>b :b 
nnoremap <Leader>n :bn<CR>
nnoremap <Leader>p :bp<CR>
" Delete buffer, but preserve panes
nnoremap <Leader>d :bp \| bd #<cr>

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
" NerdCommenter
"
" Mappings to add:
" Debugging remaps
