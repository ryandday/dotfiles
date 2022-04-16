syntax on
filetype plugin indent on
set nocompatible
inoremap jk <ESC>
set laststatus=2
set hidden " enable changing buffers without saving
set lazyredraw
set encoding=utf-8
set cursorline
set linebreak
set undolevels=1000
" Disable modelines, bc its a possible security risk
set modelines=0
set nomodeline
set updatetime=100
"no gruvbox
" set t_Co=256
" colorscheme desert

let mapleader = " "
" Prevent leader key from inserting a space 
nnoremap <SPACE> <Nop> 

set tabstop=2 " number of visual spaces per TAB
set shiftwidth=2 " '>' uses spaces
set expandtab "insert spaces on tab
set list
set listchars=tab:>~ " Show tab characters as symbols

set number
set relativenumber
" Toggle relative line numbering
nnoremap <Leader>rr :set norelativenumber!<CR>
nnoremap <Leader>z :source ~/.vimrc<CR> 
 
"--- Backups ---
set undofile
set backup
set noswapfile
" set cached vim stuff in its own directory
set undodir=~/.vim/.undo//
set backupdir=~/.vim/.backup//
set directory=~/.vim/.swp//

"--- Copy and Paste ---
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

"--- Search and Navigation ---
set path+=** " adds all files in cwd for find
set wildmenu
set wildmode=longest,list
set incsearch " when searching, put cursor on next occurrence
set ignorecase " ignore case when searching
set wildignorecase 
set wildignore+=**/*.pyc*/**
set wildignore+=**/*pycache*/**
set wildignore+=**/*cpython*/**
set wildignore+=build*/**

" vim splits 
nnoremap <Leader>j <C-w>j 
nnoremap <Leader>k <C-w>k 
nnoremap <Leader>l <C-w>l 
nnoremap <Leader>h <C-w>h 
set splitbelow
set splitright

nnoremap <Leader>b :Buffers<CR>
nnoremap <Leader>d :bd<CR>

nnoremap <Leader>fn :Rg<CR>
nnoremap <Leader>ff :GFiles<CR>

nnoremap <Leader>lc :lclose<CR>
nnoremap <Leader>lo :lopen<CR>
nnoremap ]l :lnext<CR>
nnoremap [l :lprev<CR>

nnoremap <Leader>cc :cclose<CR>
nnoremap <Leader>co :copen<CR>
nnoremap ]q :cn<CR>
nnoremap [q :cp<CR>

nnoremap <Leader>tc :tabclose<CR>
nnoremap <Leader>to :tabnew<CR>
nnoremap ]t :tabnext<CR>
nnoremap [t :tabprev<CR>

" replace in current file 
nnoremap <leader>rl :execute '%s/'.expand('<cword>').'//gc'<Left><Left><Left><Left>

command! WipeNoNameBuffers call s:wipe_no_name_buffers()
function! s:wipe_no_name_buffers()
  let bufinfos = getbufinfo()
  for bufinfo in bufinfos
    if bufinfo['name'] == ""
      execute "bw ".bufinfo['bufnr']
    endif
  endfor 
endfunction

"--- Netrw Settings ---
let g:netrw_banner=0
let g:netrw_bufsettings = 'noma nomod nu nobl nowrap ro' " Set line numbers in netrw
let g:netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+' " hide dotfiles in netrw - turn back on with gh
let g:netrw_fastbrowse=0 " turn off persistent hidden buffer behavior
nnoremap - :E .<CR>
nnoremap <Leader>E :E .<CR>

"--- Cpp --- 
" switch between header and cpp files 
nnoremap <Leader>tp :find %:t:r.cpp<CR>
nnoremap <Leader>th :find %:t:r.h<CR>

command! BuildMake call s:buildMake()
function! s:buildMake()
  cd build
  make -j 
  cd ..
endfunction

nnoremap <Leader>m :BuildMake<cr><cr><cr>

let g:termdebug_wide=1

"--- Git Shortcuts ---
nnoremap <leader>gd :Gvdiffsplit<CR>
nnoremap <leader>gs :G<CR>
nnoremap <leader>ga :G add .<CR>
nnoremap <leader>gr :GRename<space>
nnoremap <leader>gm :GMove<space>
nnoremap <leader>gp :G push<CR>
nnoremap <leader>gc :G commit<CR>

"--- Plugins ---
call plug#begin('~/.vim/plugged')
  " Fuzzy find
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  " Syntax, color
  Plug 'bfrg/vim-cpp-modern' 
  Plug 'morhetz/gruvbox'
  " Editing tools
  Plug 'tpope/vim-surround'
  Plug 'tpope/vim-abolish'
  Plug 'tpope/vim-commentary'
  " Git
  Plug 'tpope/vim-fugitive'
  Plug 'airblade/vim-gitgutter'
  " LSP features, linting and autocomplete, 
  Plug 'dense-analysis/ale'
  Plug 'prabirshrestha/vim-lsp'
  Plug 'mattn/vim-lsp-settings'
  Plug 'prabirshrestha/asyncomplete.vim'
  Plug 'prabirshrestha/asyncomplete-lsp.vim'
call plug#end()

" Let Ale do diagnostics
let g:lsp_diagnostics_enabled = 0
nmap ]g :ALENext<cr>
nmap [g :ALEPrevious<cr>

"--- Asynccomplete
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <cr>    pumvisible() ? asyncomplete#close_popup() : "\<cr>"

"--- Gruvbox ---
colorscheme gruvbox
set bg=dark

"--- vim-lsp ---
if executable('clangd')
    au User lsp_setup call lsp#register_server({
        \ 'name': 'clangd',
        \ 'cmd': {server_info->['clangd']},
        \ 'allowlist': ['.c', '.cpp'],
        \ })
endif

function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    setlocal signcolumn=yes
    if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif
    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gs <plug>(lsp-document-symbol-search)
    nmap <buffer> gS <plug>(lsp-workspace-symbol-search)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> gt <plug>(lsp-type-definition)
    nmap <buffer> <leader>rn <plug>(lsp-rename)
    nmap <buffer> K <plug>(lsp-hover)
endfunction

augroup lsp_install
    au!
    " call s:on_lsp_buffer_enabled only for languages that has the server registered.
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

