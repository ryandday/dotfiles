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
" no gruvbox
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
"nnoremap <leader>yff :let @+=expand("%")<CR>
nnoremap <leader>yff :let @+=fnamemodify(expand("%"), ":~:.")<CR>
" yank relative path into r buffer - used for running files
"nnoremap <leader>yfr :let @r=expand("%")<CR>
nnoremap <leader>yfr :let @r=fnamemodify(expand("%"), ":~:.")<CR>
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

" vim splits 
nnoremap <Leader>j <C-w>j 
nnoremap <Leader>k <C-w>k 
nnoremap <Leader>l <C-w>l 
nnoremap <Leader>h <C-w>h 
set splitbelow
set splitright

" Buffer commands
nnoremap <Leader>b :ls<CR>:b<SPACE>
nnoremap <Leader>d :bd<CR>
nnoremap <Leader>n :bn<CR>
nnoremap <Leader>p :bp<CR>

" search working directory
nnoremap <Leader>ff :vimgrep  **/* <Left><Left><Left><Left><Left><Left>
" search working directory with word under cursor
command! VIMGREP :execute 'vimgrep '.expand('<cword>').' **/*'
nnoremap <Leader>fw :VIMGREP<CR>

nnoremap <Leader>cc :cclose<CR>
nnoremap <Leader>co :copen<CR>
nnoremap <Leader>cn :cn<CR>
nnoremap <Leader>cp :cp<CR>

" rename in current file 
nnoremap <leader>rl :execute '%s/'.expand('<cword>').'//gc'<Left><Left><Left><Left>
" rename in open buffers
nnoremap <leader>rn :execute 'bufdo %s/'.expand('<cword>').'//gec'<Left><Left><Left><Left><Left>

" Open all files in quicklist 
nnoremap <leader> oa :OpenAll<CR>
command! OpenAll call s:QuickFixOpenAll()
function! s:QuickFixOpenAll()
  if empty(getqflist())
      return
  endif
  let s:prev_value = ""
  for d in getqflist()
    let s:curr_val = bufname(d.bufnr)
    if (s:curr_val != s:prev_val)
        exec "edit " . s:curr_val
    endif
      let s:prev_val = s:curr_val
  endfor
endfunction

"--- Language Specific --- 
" switch between header and cpp files
nnoremap <Leader>tp :e %:r.cpp<CR>
nnoremap <Leader>th :e %:r.h<CR>

" run python file in register as module 
nnoremap <Leader>rp :RunPy<CR>
command! RunPy call RunPythonModule()
function! RunPythonModule()
  let filename = @r "run filename in r buffer
  let l:modulefilenamecommand = "echo ".filename." | sed -e 's/\\\//./g' -e 's/.py//g'"
  let l:modulefilename = system(l:modulefilenamecommand)
  let l:command = "python3 -m ".l:modulefilename
  echo system(l:command)
endfunction

"--- Netrw Settings ---
let g:netrw_banner=0
let g:netrw_bufsettings = 'noma nomod nu nobl nowrap ro' " Set line numbers in netrw
let g:netrw_list_hide = '\(^\|\s\s\)\zs\.\S\+' " hide dotfiles in netrw - turn back on with gh
let g:netrw_fastbrowse=0 " turn off persistent hidden buffer behavior
nnoremap - :Re<CR>
nnoremap <Leader>E :E .<CR>

" --- No-Plugin Git Utils ---

" Print line numbers modified in current file from last commit 
command! GDN call s:show_line_nums_git_diff()
" Add sign in sign column for lines modified in current file from last commit
command! GDH call s:highlight_changed()
" quickfix with all git files changed
command! -nargs=1 Gdiff call s:get_diff_files(<q-args>)
command! CM execute "sign unplace *" 
" jump to next modified line
command! NextL call s:jump_next_changed_line()
" jump to prev modified line
command! PrevL call s:jump_prev_changed_line()

nnoremap ]h :NextL<CR>
nnoremap [h :PrevL<CR>
nnoremap <leader>gh :GDH<CR>
nnoremap <leader>gc :CM<CR>
nnoremap <leader>gn :GDN<CR>

" vimdiff - swapfiles off helps
command! Difftool :execute '!git difftool '.expand(@%)
nnoremap <leader>gd :Difftool<CR>
nnoremap <leader>gq :qa!<CR>

" Separate functions for speed
function! s:jump_next_changed_line()
  let l:command = "git blame -p ".expand(@%)." | grep '0000000000000000000000000000000000000000' | awk '{print $3}'"
  let line_nums = split(system(l:command), '\n')
  let line_nums = reverse(line_nums)
  if len(line_nums)==0
    echo "No modified lines"
    return
  endif
  let curr_line = line(".")
  for line_num in line_nums
    if line_num > curr_line
      call cursor(line_num,0)
      return
    endif
  endfor
  echo "Reached beginning of modified lines"
endfunction

function! s:jump_prev_changed_line()
  let l:command = "git blame -p ".expand(@%)." | grep '0000000000000000000000000000000000000000' | awk '{print $3}'"
  let line_nums = split(system(l:command), '\n')
  let line_nums = reverse(line_nums)
  if len(line_nums)==0
    echo "No modified lines"
    return
  endif
  let curr_line = line(".")
  for line_num in line_nums
    if line_num < curr_line
      call cursor(line_num,0)
      return
    endif
  endfor
  echo "Reached end of modified lines"
endfunction

function! s:show_line_nums_git_diff()
  let l:command = "git blame -p ".expand(@%)." | grep '0000000000000000000000000000000000000000' | awk '{print $3}'"
  echom(system(command))
endfunction

sign define GitChanged text=! texthl=Search
function! s:highlight_changed()
  execute "sign unplace *" 
  let l:command = "git blame -p ".expand(@%)." | grep '0000000000000000000000000000000000000000' | awk '{print $3}'"
  let line_nums = split(system(l:command), '\n')
  for numba in line_nums
    execute ":sign place 2 line=".numba." name=GitChanged file=".expand('%:p')
  endfor
endfunction

let s:git_status_dictionary = {
      \ "A": "Added",
      \ "B": "Broken",
      \ "C": "Copied",
      \ "D": "Deleted",
      \ "M": "Modified",
      \ "R": "Renamed",
      \ "T": "Changed",
      \ "U": "Unmerged",
      \ "X": "Unknown"
      \ }

function! s:get_diff_files(rev)
  let title = 'Gdiff '.a:rev
  let command = 'git diff --name-status '.a:rev
  let lines = split(system(command), '\n')
  let items = []
  for line in lines
    let filename = matchstr(line, "\\S\\+$")
    let status = s:git_status_dictionary[matchstr(line, "^\\w")]
    let item = { "filename": filename, "text": status }
    call add(items, item)
  endfor
  let list = {'title': title, 'items': items}
  call setqflist([], 'r', list)
  copen
endfunction

"--- Plugins ---
call plug#begin('~/.vim/plugged')
  Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
  Plug 'junegunn/fzf.vim'
  Plug 'morhetz/gruvbox'
  Plug 'neoclide/coc.nvim', {'branch': 'release'}
  Plug 'puremourning/vimspector'
call plug#end()

"--- Gruvbox ---
colorscheme gruvbox
set bg=dark

"--- Vimspector ---
let g:vimspector_enable_mappings = 'HUMAN'
" VimspectorReset leaves no name buffers
nmap <leader>rq :VimspectorReset<CR>:WipeNoNameBuffers<CR>

command! WipeNoNameBuffers call s:delete_no_name_buffers() 
function! s:delete_no_name_buffers()
  let bufinfos = getbufinfo()
  for bufinfo in bufinfos
    if bufinfo['name'] == ""
      execute "bw ".bufinfo['bufnr']
    endif
  endfor 
endfunction

"--- Coc.nvim ---
" code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)
nnoremap <silent> K :call <SID>show_documentation()<CR>
inoremap <silent><expr> <C-l>  coc#refresh()
nnoremap <leader>cl :CocCommand python.enableLinting<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction
"don't give |ins-completion-menu| messages.
set shortmess+=c
set signcolumn=yes " always show signcolumns
set updatetime=300
" Use tab for trigger completion with characters ahead and navigate.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"
function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction
