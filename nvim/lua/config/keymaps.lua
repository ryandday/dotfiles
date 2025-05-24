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

-- FZF mappings
keymap('n', '<leader>d', ':Rg<cr>')
keymap('n', '<leader>s', ':GFiles<cr>')
keymap('n', '<leader>ff', ':Files<cr>')
keymap('n', '<leader>fn', ':grep! "" <left><left>')

-- Search current word
keymap('n', '<leader>fw', function()
  vim.cmd('grep! ' .. vim.fn.expand('<cword>'))
  vim.cmd('copen')
end)

-- Replace mappings
keymap('n', '<leader>rl', ':%s/<c-r><c-w>//gc<left><left><left>')
keymap('n', '<leader>rg', function()
  vim.cmd('grep! ' .. vim.fn.expand('<cword>'))
  vim.cmd('cfdo %s/' .. vim.fn.expand('<cword>') .. '//gec<left><left><left><left>')
end)

-- Buffer mappings
keymap('n', '<leader>b', ':Buffers<cr>')
keymap('n', '<leader>x', ':bd!<cr>')

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

-- C++ header/source switching
local function find_or_open(file)
  local bufnum = vim.fn.bufnr(file)
  if bufnum ~= -1 then
    vim.cmd('buffer ' .. bufnum)
  else
    vim.cmd('find ' .. file)
  end
end

keymap('n', '<leader>tp', function()
  find_or_open(vim.fn.expand('%:t:r') .. '.cpp')
end)

keymap('n', '<leader>th', function()
  find_or_open(vim.fn.expand('%:t:r') .. '.h')
end)

-- Build and test mappings
keymap('n', '<leader>m', function()
  vim.cmd('Make -j -C build')
end)

keymap('n', '<leader>tt', function()
  if vim.fn.fnamemodify(vim.fn.getcwd(), ':t') ~= 'build' then
    vim.cmd('cd build')
  end
  vim.cmd('Dispatch ctest -VV')
  vim.cmd('cd ..')
end)

-- Git mappings (fugitive)
keymap('n', '<leader>gd', ':Gvdiffsplit<cr>')
keymap('n', '<leader>gs', ':G<cr>')
keymap('n', '<leader>gp', ':G push<cr>')
keymap('n', '<leader>gb', ':G blame<cr>')
keymap('n', '<leader>gl', ':Gclog<cr>')
keymap('n', '<leader>gf', ':Flogsplit -path=%<cr>')
keymap('v', '<leader>gf', ':Flog<cr>')
keymap('n', '<leader>gg', ':Gbranch<cr>')

-- Debugging mappings (termdbg)
keymap('n', '<F9>', ':TToggleBreak<cr>')
keymap('n', '<F7>', ':TNext<cr>')
keymap('n', '<F8>', ':TStep<cr>')
keymap('n', '<F5>', ':TContinue<cr>')

-- Diagnostic navigation
keymap('n', ']g', '<cmd>lua vim.diagnostic.goto_next()<cr>')
keymap('n', '[g', '<cmd>lua vim.diagnostic.goto_prev()<cr>')
keymap('n', '<leader>e', '<cmd>lua vim.diagnostic.open_float()<cr>')

-- LSP mappings
keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<cr>')
keymap('n', 'gs', '<cmd>lua vim.lsp.buf.document_symbol()<cr>')
keymap('n', 'gS', '<cmd>lua vim.lsp.buf.workspace_symbol()<cr>')
keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<cr>')
keymap('n', 'gt', '<cmd>lua vim.lsp.buf.type_definition()<cr>')
keymap('n', '<leader>rn', '<cmd>lua vim.lsp.buf.rename()<cr>')
keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<cr>')
keymap('n', '<leader>ca', '<cmd>lua vim.lsp.buf.code_action()<cr>')
keymap('n', '<leader>f', '<cmd>lua vim.lsp.buf.format({ async = true })<cr>')

-- Trouble mappings
keymap('n', '<leader>xx', '<cmd>Trouble<cr>')
keymap('n', '<leader>xd', '<cmd>Trouble document_diagnostics<cr>')
keymap('n', '<leader>xw', '<cmd>Trouble workspace_diagnostics<cr>')
keymap('n', '<leader>ch', '<cmd>lua vim.lsp.buf.incoming_calls()<cr>')
keymap('n', '<leader>cH', '<cmd>lua vim.lsp.buf.outgoing_calls()<cr>') 