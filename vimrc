"--- Basics ---
syntax on
filetype plugin indent on

set nocompatible
inoremap jk <esc>
set laststatus=2 " always show statusbar
set hidden " enable changing buffers without saving
set lazyredraw
set ttyfast
set encoding=utf-8
set cursorline
set linebreak
set scrolloff=8
set undolevels=1000
set modelines=0 " disable modelines, bc its a possible security risk
set nomodeline
set updatetime=50
set visualbell
set t_vb=
set noerrorbells
set diffopt+=vertical

" see :h xterm-true-color
if exists('+termguicolors')
  let &t_8f="\<Esc>[38;2;%lu;%lu;%lum"
  let &t_8b="\<Esc>[48;2;%lu;%lu;%lum"
  set termguicolors
endif

let mapleader = " "
" prevent leader key from inserting a space 
nnoremap <space> <nop> 

set list
set listchars=tab:>~ " Show tab characters as symbols
set listchars+=trail:· " Show trailing whitespace as symbols
set tabstop=2 " number of visual spaces per tab
set shiftwidth=2 " '>' uses spaces
set expandtab " insert spaces on tab
autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o " don't auto comment on newline after comment
set backspace=indent,eol,start " allow backspacing in insert mode

set number
set relativenumber
" toggle line numbering
nnoremap <leader>rr :set norelativenumber!<cr>:set nonumber!<cr>
nnoremap <leader>z :source ~/.vimrc<cr> 
nnoremap <leader>w :update<cr>
 
"--- Backups ---
set undofile
set backup
set noswapfile

" set cached vim stuff in its own directory
set backupdir=~/.vim/.backup//
set directory=~/.vim/.swp//

" neovim has different undo format, so separate the folders
" so that vim doesn't get confused
if has("nvim")
  set undodir=~/.vim/.undonvim//
else
  set undodir=~/.vim/.undo//
endif


"--- Copy and Paste ---
" use system clipboard as default copy buffer
set clipboard^=unnamed,unnamedplus
" yank relative path + line number
nnoremap <leader>yf :let @+=expand("%") . ':' . line('.')<CR>
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
set wildignore+=**/*build*/**
set wildignore+=**/*MakeFile*/**
set wildignore+=**/*CMakeFiles*/**
set wildignore+=**/*.a*/**
set wildignore+=**/*.o*/**

" when searching or navigating, center the cursor vertically
nnoremap n nzz
nnoremap N Nzz
nnoremap <c-d> <c-d>zz
nnoremap <c-u> <c-u>zz

set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case\ --ignore-file\ .gitignore
nnoremap <leader>d :Rg<cr>

nnoremap <leader>s :GFiles<cr>
nnoremap <leader>ff :Files<cr>
nnoremap <leader>fn :grep! "" <left><left>
command! VIMGREPCURRWORD :execute 'grep! '.expand('<cword>')
nnoremap <leader>fw :VIMGREPCURRWORD<cr><cr>:copen<cr>

" replace in current file 
nnoremap <leader>rl :%s/<c-r><c-w>//gc<left><left><left>
" replace globally
nnoremap <leader>rg :VIMGREPCURRWORD<cr>:cfdo %s/<c-r><c-w>//gec<left><left><left><left>

"--- Buffers ---
nnoremap <leader>b :Buffers<cr>
nnoremap <leader>x :bd!<cr>

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
nnoremap <leader>k :cf<cr>
nnoremap <leader>K :cfirst<cr>
nnoremap <leader>j :clast<cr>
nnoremap <c-k> :cp<cr>zz
nnoremap <c-j> :cn<cr>zz

nnoremap <leader>tl :tabclose<cr>
nnoremap <leader>to :tabnew<cr>
nnoremap ]t :tabnext<cr>
nnoremap [t :tabprev<cr>

"--- Netrw Settings ---
let g:netrw_banner=0
let g:netrw_bufsettings = 'noma nomod nu nobl nowrap ro' " set line numbers in netrw
let g:netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+' " hide dotfiles in netrw - turn back on with gh

nnoremap <leader>E :E .<cr>

" Make netrw highlight the previously active directory / file
function! NetrwUpDirectory()
  if &filetype == 'netrw'
    let l:current_dir = expand('%:p:h')
    let l:parent_dir = fnamemodify(l:current_dir, ':h')
    execute 'Explore ' . fnameescape(l:parent_dir)
    call search(fnamemodify(l:current_dir, ':t'), 'w')
  else
    let l:file_name = expand('%:t')
    let l:file_dir = expand('%:p:h')
    execute 'Explore ' . fnameescape(l:file_dir)
    call search('\V' . escape(l:file_name, '\'))
  endif
endfunction

nnoremap - :call NetrwUpDirectory()<CR>

"--- Python ---
autocmd FileType python setlocal shiftwidth=4 tabstop=4 expandtab

"--- Cpp --- 
" switch between header and cpp files 
function! FindOrOpen(file)
  let bufnum = bufnr(a:file)

  if bufnum != -1
    execute 'buffer' bufnum
  else
    execute 'find' a:file
  endif
endfunction

nnoremap <leader>tp :call FindOrOpen(expand('%:t:r') . '.cpp')<cr>
nnoremap <leader>th :call FindOrOpen(expand('%:t:r') . '.h')<cr>

autocmd FileType cpp setlocal shiftwidth=2 tabstop=2 expandtab

command! BuildMake call s:buildMake()
function! s:buildMake()
  Make -j -C build
endfunction

nnoremap <leader>m :BuildMake<cr><cr><cr>

command! RunTests call s:runTests()
function! s:runTests()
  if fnamemodify(getcwd(), ':t') != "build"
    cd build
  endif
  Dispatch ctest -VV 
  cd ..
endfunction

nnoremap <leader>tt :RunTests<cr><cr><cr>
let g:termdebug_wide=1

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
  Plug 'tpope/vim-repeat'
  " Async
  Plug 'tpope/vim-dispatch'
  Plug 'nvim-lua/plenary.nvim'
  " Git
  Plug 'tpope/vim-fugitive'
  Plug 'tpope/vim-rhubarb'
  Plug 'airblade/vim-gitgutter'
  Plug 'rbong/vim-flog'
  " File explorer
  Plug 'preservim/nerdtree'
  Plug 'PhilRunninger/nerdtree-buffer-ops'
  Plug 'nvim-tree/nvim-web-devicons'
  " LSP
  Plug 'neovim/nvim-lspconfig'
  Plug 'williamboman/mason.nvim'
  Plug 'williamboman/mason-lspconfig.nvim'
  Plug 'nvimtools/none-ls.nvim'
  " Completion/snippets
  Plug 'hrsh7th/nvim-cmp'
  Plug 'hrsh7th/cmp-nvim-lsp'
  Plug 'hrsh7th/cmp-buffer'
  Plug 'hrsh7th/cmp-path'
  Plug 'hrsh7th/cmp-cmdline'
  Plug 'L3MON4D3/LuaSnip'
  Plug 'saadparwaiz1/cmp_luasnip'
  " Diagnostics
  Plug 'folke/trouble.nvim'
  Plug 'nvim-telescope/telescope.nvim'
  Plug 'nvim-treesitter/nvim-treesitter'
  Plug 'wellle/context.vim'
  " Debugging
  Plug 'epheien/termdbg' " for lldb
call plug#end()

"--- vim-fugitive ---
nnoremap <leader>gd :Gvdiffsplit<cr>
nnoremap <leader>gs :G<cr>
nnoremap <leader>gp :G push<cr>
nnoremap <leader>gb :G blame<cr>
nnoremap <leader>gl :Gclog<cr>
nnoremap <leader>gf :Flogsplit -path=%<cr>
vnoremap <leader>gf :Flog<cr>

function! GitCheckoutBranch(branch)
    let l:name = split(split(trim(a:branch), "", 1)[0], "/", 1)[-1]
    execute "G checkout ".l:name
endfunction

command! -bang Gbranch call fzf#run(fzf#wrap({'source': 'git branch -avv --color', 'sink': function('GitCheckoutBranch'), 'options': '--ansi --nth=1'}, <bang>0))
nnoremap <leader>gg :Gbranch<cr>

"--- asynccomplete ---

"--- gruvbox ---
colorscheme gruvbox
set bg=dark
" Settings to help with transparent background
" let g:gruvbox_transparent_bg = 1
" hi! Normal guibg=NONE ctermbg=NONE

"--- termdbg ---
nnoremap <F9> :TToggleBreak<cr>
nnoremap <F7> :TNext<cr>
nnoremap <F8> :TStep<cr>
nnoremap <F5> :TContinue<cr>


"-- fzf --
" Allow scrolling when previewing
let $FZF_DEFAULT_OPTS="--bind ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down,ctrl-y:preview-up,ctrl-e:preview-down,ctrl-b:page-up,ctrl-f:page-down"

lua << EOF
local cmp = require('cmp')
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      else
        fallback()
      end
    end),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  })
})
EOF

" === Diagnostic navigation (replaces ALE mappings) ===
nnoremap ]g <cmd>lua vim.diagnostic.goto_next()<cr>
nnoremap [g <cmd>lua vim.diagnostic.goto_prev()<cr>
nnoremap <leader>e <cmd>lua vim.diagnostic.open_float()<cr>

" === LSP mappings (replaces vim-lsp mappings) ===
nnoremap gd <cmd>lua vim.lsp.buf.definition()<cr>
nnoremap gs <cmd>lua vim.lsp.buf.document_symbol()<cr>
nnoremap gS <cmd>lua vim.lsp.buf.workspace_symbol()<cr>
nnoremap gr <cmd>lua vim.lsp.buf.references()<cr>
nnoremap gt <cmd>lua vim.lsp.buf.type_definition()<cr>
nnoremap <leader>rn <cmd>lua vim.lsp.buf.rename()<cr>
nnoremap K <cmd>lua vim.lsp.buf.hover()<cr>
nnoremap <leader>ca <cmd>lua vim.lsp.buf.code_action()<cr>
nnoremap <leader>f <cmd>lua vim.lsp.buf.format({ async = true })<cr>

" === Trouble mappings (enhanced diagnostics) ===
nnoremap <leader>xx <cmd>Trouble<cr>
nnoremap <leader>xd <cmd>Trouble document_diagnostics<cr>
nnoremap <leader>xw <cmd>Trouble workspace_diagnostics<cr>
nnoremap <leader>ch <cmd>lua vim.lsp.buf.incoming_calls()<cr>
nnoremap <leader>cH <cmd>lua vim.lsp.buf.outgoing_calls()<cr>

" === LSP Setup (replaces your ccls and lsp configuration) ===
lua << EOF
-- Mason setup
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "clangd", "pyright" },
  automatic_installation = true,
})

-- LSP configuration
local lspconfig = require('lspconfig')
local cmp_nvim_lsp = require('cmp_nvim_lsp')
local capabilities = cmp_nvim_lsp.default_capabilities()

-- Sign column always on for LSP
vim.opt.signcolumn = "yes"

-- C/C++ setup (replaces your ccls config)
lspconfig.clangd.setup({
  capabilities = capabilities,
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-style=llvm",
  },
  root_dir = lspconfig.util.root_pattern(
    '.clangd',
    '.clang-tidy', 
    '.clang-format',
    'compile_commands.json',
    'compile_flags.txt',
    '.ccls',
    '.git'
  ),
  init_options = {
    cache = {
      directory = vim.fn.expand('~/.cache/clangd')
    }
  }
})

-- Python setup
lspconfig.pyright.setup({
  capabilities = capabilities,
})

-- Diagnostic configuration
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})

-- Completion setup
local cmp = require('cmp')
local luasnip = require('luasnip')

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'buffer' },
    { name = 'path' },
  })
})

-- Trouble setup
require("trouble").setup()
EOF
