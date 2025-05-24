-- Keymaps
local keymap = vim.keymap.set

-- Prevent leader key from inserting a space
keymap('n', '<space>', '<nop>')

-- Escape mapping
keymap('i', 'jk', '<esc>')

-- Line numbering toggle
keymap('n', '<leader>rr', ':set norelativenumber!<cr>:set nonumber!<cr>')

-- Source vimrc
keymap('n', '<leader>z', ':source ~/.config/nvim/init.lua<cr>')

-- Save file
keymap('n', '<leader>w', ':update<cr>')

-- Copy and paste mappings
-- yank relative path + line number
keymap('n', '<leader>yf', function()
  local path_line = vim.fn.expand('%') .. ':' .. vim.fn.line('.')
  vim.fn.setreg('+', path_line)
end)

-- yank absolute path
keymap('n', '<leader>ya', function()
  vim.fn.setreg('+', vim.fn.expand('%:p'))
end)

-- yank filename
keymap('n', '<leader>yt', function()
  vim.fn.setreg('+', vim.fn.expand('%:t'))
end)

-- yank directory name
keymap('n', '<leader>yh', function()
  vim.fn.setreg('+', vim.fn.expand('%:p:h'))
end)

-- Search and navigation
keymap('n', 'n', 'nzz')
keymap('n', 'N', 'Nzz')
keymap('n', '<c-d>', '<c-d>zz')
keymap('n', '<c-u>', '<c-u>zz')

-- Replace mappings
keymap('n', '<leader>rl', ':%s/<c-r><c-w>//gc<left><left><left>')
keymap('n', '<leader>rg', function()
  vim.cmd('grep! ' .. vim.fn.expand('<cword>'))
  vim.cmd('cfdo %s/' .. vim.fn.expand('<cword>') .. '//gec<left><left><left><left>')
end)

-- Buffer mappings
-- keymap('n', '<leader>x', ':bd!<cr>')

-- Location list mappings
keymap('n', '<leader>lc', ':lclose<cr>')
keymap('n', '<leader>lo', ':lopen<cr>')
keymap('n', ']l', ':lnext<cr>')
keymap('n', '[l', ':lprev<cr>')
keymap('n', '[L', ':lfirst<cr>')
keymap('n', ']L', ':llast<cr>')

-- Quickfix mappings
keymap('n', '<leader>cc', ':cclose<cr>')
keymap('n', '<leader>co', ':copen<cr>')
keymap('n', '<leader>k', ':cf<cr>')
keymap('n', '<leader>K', ':cfirst<cr>')
keymap('n', '<leader>j', ':clast<cr>')
keymap('n', '<c-k>', ':cp<cr>zz')
keymap('n', '<c-j>', ':cn<cr>zz')

-- Tab mappings
keymap('n', '<leader>tl', ':tabclose<cr>')
keymap('n', '<leader>to', ':tabnew<cr>')
keymap('n', ']t', ':tabnext<cr>')
keymap('n', '[t', ':tabprev<cr>')

-- Netrw mappings
keymap('n', '<leader>E', ':E .<cr>')

-- Custom netrw up directory function
local function netrw_up_directory()
  if vim.bo.filetype == 'netrw' then
    local current_dir = vim.fn.expand('%:p:h')
    local parent_dir = vim.fn.fnamemodify(current_dir, ':h')
    vim.cmd('Explore ' .. vim.fn.fnameescape(parent_dir))
    vim.fn.search(vim.fn.fnamemodify(current_dir, ':t'), 'w')
  else
    local file_name = vim.fn.expand('%:t')
    local file_dir = vim.fn.expand('%:p:h')
    vim.cmd('Explore ' .. vim.fn.fnameescape(file_dir))
    vim.fn.search('\\V' .. vim.fn.escape(file_name, '\\'))
  end
end

keymap('n', '-', netrw_up_directory)

-- Build and test mappings
keymap('n', '<leader>m', function()
  vim.cmd('Make -j -C build')
end)

keymap('n', '<leader>rt', function()
  if vim.fn.fnamemodify(vim.fn.getcwd(), ':t') ~= 'build' then
    vim.cmd('cd build')
  end
  vim.cmd('Dispatch ctest -VV')
  vim.cmd('cd ..')
end)
