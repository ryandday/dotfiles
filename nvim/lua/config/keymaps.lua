-- Keymaps
local keymap = vim.keymap.set

-- Prevent leader key from inserting a space
keymap('n', '<space>', '<nop>', { desc = 'Disable space in normal mode' })

-- Escape mapping
keymap('i', 'jk', '<esc>', { desc = 'Exit insert mode' })

-- Line numbering toggle
keymap('n', '<leader>rr', ':set norelativenumber!<cr>:set nonumber!<cr>', { desc = 'Toggle line numbers' })

-- Source vimrc
keymap('n', '<leader>z', ':source ~/.config/nvim/init.lua<cr>', { desc = 'Reload nvim config' })

-- Save file
keymap('n', '<leader>w', ':update<cr>', { desc = 'Save file' })

-- Copy and paste mappings
-- yank relative path + line number
keymap('n', '<leader>yf', function()
  local path_line = vim.fn.expand('%') .. ':' .. vim.fn.line('.')
  vim.fn.setreg('+', path_line)
end, { desc = 'Yank file path with line number' })

-- yank absolute path
keymap('n', '<leader>ya', function()
  vim.fn.setreg('+', vim.fn.expand('%:p'))
end, { desc = 'Yank absolute file path' })

-- yank filename
keymap('n', '<leader>yt', function()
  vim.fn.setreg('+', vim.fn.expand('%:t'))
end, { desc = 'Yank filename' })

-- yank directory name
keymap('n', '<leader>yh', function()
  vim.fn.setreg('+', vim.fn.expand('%:p:h'))
end, { desc = 'Yank directory path' })

-- Clean whitespace - remove trailing whitespace and whitespace-only lines
keymap('n', '<leader>cw', function()
  local save_cursor = vim.fn.getpos('.')
  -- Remove trailing whitespace
  vim.cmd([[%s/\s\+$//e]])
  -- Remove whitespace from empty lines (lines with only whitespace become truly empty)
  vim.cmd([[%s/^\s\+$//e]])
  -- Restore cursor position
  vim.fn.setpos('.', save_cursor)
end, { desc = 'Clean whitespace' })

-- Search and navigation
keymap('n', 'n', 'nzz', { desc = 'Next search result (centered)' })
keymap('n', 'N', 'Nzz', { desc = 'Previous search result (centered)' })
keymap('n', '<c-d>', '<c-d>zz', { desc = 'Half page down (centered)' })
keymap('n', '<c-u>', '<c-u>zz', { desc = 'Half page up (centered)' })

-- Replace mappings
keymap('n', '<leader>rl', ':%s/<c-r><c-w>//gc<left><left><left>', { desc = 'Replace word under cursor (local)' })
keymap('n', '<leader>rg', function()
  vim.cmd('grep! ' .. vim.fn.expand('<cword>'))
  vim.cmd('cfdo %s/' .. vim.fn.expand('<cword>') .. '//gec<left><left><left><left>')
end, { desc = 'Replace word under cursor (global)' })

-- Buffer mappings
-- keymap('n', '<leader>x', ':bd!<cr>', { desc = 'Delete buffer' })

-- Location list mappings
keymap('n', '<leader>lc', ':lclose<cr>', { desc = 'Close location list' })
keymap('n', '<leader>lo', ':lopen<cr>', { desc = 'Open location list' })
keymap('n', ']l', ':lnext<cr>', { desc = 'Next location' })
keymap('n', '[l', ':lprev<cr>', { desc = 'Previous location' })
keymap('n', '[L', ':lfirst<cr>', { desc = 'First location' })
keymap('n', ']L', ':llast<cr>', { desc = 'Last location' })

-- Quickfix mappings
keymap('n', '<leader>cc', ':cclose<cr>', { desc = 'Close quickfix' })
keymap('n', '<leader>co', ':copen<cr>', { desc = 'Open quickfix' })
keymap('n', '<leader>k', ':cf<cr>', { desc = 'Quickfix first' })
keymap('n', '<leader>K', ':cfirst<cr>', { desc = 'Quickfix first' })
keymap('n', '<leader>j', ':clast<cr>', { desc = 'Quickfix last' })
keymap('n', '<c-k>', ':cp<cr>zz', { desc = 'Previous quickfix (centered)' })
keymap('n', '<c-j>', ':cn<cr>zz', { desc = 'Next quickfix (centered)' })

-- Tab mappings
keymap('n', '<leader>tl', ':tabclose<cr>', { desc = 'Close tab' })
keymap('n', '<leader>to', ':tabnew<cr>', { desc = 'New tab' })
keymap('n', ']t', ':tabnext<cr>', { desc = 'Next tab' })
keymap('n', '[t', ':tabprev<cr>', { desc = 'Previous tab' })

-- Build and test mappings
keymap('n', '<leader>m', function()
  vim.cmd('Make -j -C build')
end, { desc = 'Build project' })

keymap('n', '<leader>rt', function()
  if vim.fn.fnamemodify(vim.fn.getcwd(), ':t') ~= 'build' then
    vim.cmd('cd build')
  end
  vim.cmd('Dispatch ctest -VV')
  vim.cmd('cd ..')
end, { desc = 'Run tests' })
