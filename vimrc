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

let mapleader = " "
" Prevent leader key from inserting a space 
nnoremap <space> <nop> 

set tabstop=2 " number of visual spaces per TAB
set shiftwidth=2 " '>' uses spaces
set expandtab "insert spaces on tab
set list
set listchars=tab:>~ " Show tab characters as symbols

set number
set relativenumber
" Toggle relative line numbering
nnoremap <leader>rr :set norelativenumber!<cr>
nnoremap <leader>z :source ~/.vimrc<cr> 
 
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
nnoremap <leader>yf :let @+=expand("%")<cr>
" yank absolute path
nnoremap <leader>ya :let @+=expand("%:p")<cr>
" yank filename
nnoremap <leader>yt :let @+=expand("%:t")<cr>
" yank directory name
nnoremap <leader>yh :let @+=expand("%:p:h")<cr>

"--- Search, Replace, and Navigation ---
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

if executable('rg')
  set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case
endif

nnoremap <leader>ff :GFiles<cr>
nnoremap <leader>fn :grep! "" **/* <Left><Left><Left><Left><Left><Left><Left>
command! VIMGREPCURRWORD :execute 'grep! '.expand('<cword>').' **/*'
nnoremap <leader>fw :VIMGREPCURRWORD<cr><cr>:copen<cr>

" replace in current file 
nnoremap <leader>rl :execute '%s/'.expand('<cword>').'//gc'<Left><Left><Left><Left>
" replace globally
nnoremap <leader>rg :VIMGREPCURRWORD<cr>:execute 'cfdo %s/'.expand('<cword>').'//gec'<Left><Left><Left><Left><Left>

"--- Buffers ---
nnoremap <leader>b :Buffers<cr>
nnoremap <leader>d :bd<cr>

command! WipeNoNameBuffers call s:wipe_no_name_buffers()
function! s:wipe_no_name_buffers()
  let bufinfos = getbufinfo()
  for bufinfo in bufinfos
    if bufinfo['name'] == ""
      execute "bw ".bufinfo['bufnr']
    endif
  endfor 
endfunction

"--- Windows --- 
nnoremap <leader>j <C-w>j 
nnoremap <leader>k <C-w>k 
nnoremap <leader>l <C-w>l 
nnoremap <leader>h <C-w>h 
set splitbelow
set splitright

"--- Bracket mappings ---
nnoremap <leader>lc :lclose<cr>
nnoremap <leader>lo :lopen<cr>
nnoremap ]l :lnext<cr>
nnoremap [l :lprev<cr>
nnoremap [L :lfirst<cr>
nnoremap ]L :llast<cr>

nnoremap <leader>cc :cclose<cr>
nnoremap <leader>co :copen<cr>
nnoremap ]q :cn<cr>
nnoremap [q :cp<cr>
nnoremap [Q :cfirst<cr>
nnoremap ]Q :clast<cr>

nnoremap <leader>tc :tabclose<cr>
nnoremap <leader>to :tabnew<cr>
nnoremap ]t :tabnext<cr>
nnoremap [t :tabprev<cr>

"--- Netrw Settings ---
let g:netrw_banner=0
let g:netrw_bufsettings = 'noma nomod nu nobl nowrap ro' " Set line numbers in netrw
let g:netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+' " hide dotfiles in netrw - turn back on with gh
let g:netrw_fastbrowse=0 " turn off persistent hidden buffer behavior
nnoremap - :E .<cr>
nnoremap <leader>E :E .<cr>

"--- Cpp --- 
" switch between header and cpp files 
nnoremap <leader>tp :find %:t:r.cpp<cr>
nnoremap <leader>th :find %:t:r.h<cr>

command! BuildMake call s:buildMake()
function! s:buildMake()
  cd build
  make -j 
  cd ..
endfunction

nnoremap <leader>m :BuildMake<cr><cr><cr>
let g:termdebug_wide=1

"--- Git Shortcuts ---
nnoremap <leader>gd :Gvdiffsplit<cr>
nnoremap <leader>gs :G<cr>
nnoremap <leader>ga :G add -A<cr>
nnoremap <leader>gr :GRename<space>
nnoremap <leader>gm :GMove<space>
nnoremap <leader>gp :G push<cr>
nnoremap <leader>gc :G commit<cr>
nnoremap <leader>gb :G blame<cr>
nnoremap <leader>gl :Gclog<cr>

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

"--- asynccomplete ---
inoremap <expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <expr> <cr>    pumvisible() ? asyncomplete#close_popup() : "\<cr>"

"--- gruvbox ---
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

