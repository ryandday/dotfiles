-- Basic Neovim settings
local opt = vim.opt
local g = vim.g

-- Basics
vim.cmd('syntax on')
vim.cmd('filetype plugin indent on')

opt.compatible = false
opt.laststatus = 2 -- always show statusbar
opt.hidden = true -- enable changing buffers without saving
opt.lazyredraw = true
opt.ttyfast = true
opt.encoding = 'utf-8'
opt.cursorline = true
opt.linebreak = true
opt.scrolloff = 8
opt.undolevels = 1000
opt.modelines = 0 -- disable modelines, bc its a possible security risk
opt.modeline = false
opt.updatetime = 50
opt.visualbell = true
opt.errorbells = false
opt.diffopt:append('vertical')

-- True color support
if vim.fn.exists('+termguicolors') == 1 then
  opt.termguicolors = true
end

-- Leader key
g.mapleader = ' '

-- List characters and indentation
opt.list = true
opt.listchars = {
  tab = '>~',
  trail = '·'
}
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.backspace = { 'indent', 'eol', 'start' }

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Backups and undo
opt.undofile = true
opt.backup = true
opt.swapfile = false

-- Set cached vim stuff in its own directory
opt.backupdir = vim.fn.expand('~/.vim/.backup//')
opt.directory = vim.fn.expand('~/.vim/.swp//')

-- Neovim has different undo format, so separate the folders
if vim.fn.has('nvim') == 1 then
  opt.undodir = vim.fn.expand('~/.vim/.undonvim//')
else
  opt.undodir = vim.fn.expand('~/.vim/.undo//')
end

-- Copy and paste
opt.clipboard:prepend({ 'unnamed', 'unnamedplus' })

-- Search and navigation
opt.path:append('**') -- adds all files in cwd for find
opt.wildmenu = true
opt.wildmode = { 'longest', 'list' }
opt.incsearch = true
opt.ignorecase = true
opt.wildignorecase = true
opt.wildignore:append({
  '**/*.pyc*/**',
  '**/*pycache*/**',
  '**/*cpython*/**',
  '**/*build*/**',
  '**/*MakeFile*/**',
  '**/*CMakeFiles*/**',
  '**/*.a*/**',
  '**/*.o*/**'
})

-- Grep program
opt.grepprg = 'rg --vimgrep --no-heading --smart-case --ignore-file .gitignore'

-- Windows
opt.splitbelow = true
opt.splitright = true

-- Netrw settings
g.netrw_banner = 0
g.netrw_bufsettings = 'noma nomod nu nobl nowrap ro'
g.netrw_list_hide = '\\(^\\|\\s\\s\\)\\zs\\.\\S\\+'

-- Sign column always on for LSP
opt.signcolumn = 'yes'

-- Format options
vim.api.nvim_create_autocmd('FileType', {
  pattern = '*',
  callback = function()
    vim.opt_local.formatoptions:remove({ 'c', 'r', 'o' })
  end,
})

-- Python specific
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.expandtab = true
  end,
})

-- C++ specific
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'cpp',
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.expandtab = true
  end,
}) 