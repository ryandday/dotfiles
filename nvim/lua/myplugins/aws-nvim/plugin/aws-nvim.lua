-- aws-nvim.lua - AWS resource visualization in Neovim
-- Maintainer: Ryan Day
-- Version: 0.1

-- Prevent loading multiple times
if vim.g.loaded_aws_nvim == 1 then
  return
end
vim.g.loaded_aws_nvim = 1

-- Define user commands
vim.api.nvim_create_user_command('AWSNvimOpen', function()
  require('aws-nvim').open_explorer()
end, {})

vim.api.nvim_create_user_command('AwsExplorer', function()
  require('aws-nvim').open_explorer()
end, { desc = 'Open AWS Explorer' })

vim.api.nvim_create_user_command('AWSNvimStack', function(opts)
  require('aws-nvim').open_stack(opts.args)
end, {nargs = '?'})

vim.api.nvim_create_user_command('AWSNvimRefresh', function()
  require('aws-nvim').refresh()
end, {})

vim.api.nvim_create_user_command('AWSNvimFilter', function(opts)
  require('aws-nvim').filter(opts.args)
end, {nargs = '?'})

vim.api.nvim_create_user_command('AWSNvimProfile', function(opts)
  require('aws-nvim').set_profile(opts.args)
end, {nargs = '?'})

vim.api.nvim_create_user_command('AWSNvimRegion', function(opts)
  require('aws-nvim').set_region(opts.args)
end, {nargs = '?'})

vim.api.nvim_create_user_command('AwsClearCache', function()
  require('aws-nvim').clear_cache()
end, { desc = 'Clear AWS cache' })

-- Create auto commands for the AWS explorer buffer
local aws_group = vim.api.nvim_create_augroup('aws_nvim', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = aws_group,
  pattern = 'aws-nvim',
  callback = function()
    -- Set buffer-local keymaps
    local opts = { noremap = true, silent = true, buffer = 0 }
    vim.keymap.set('n', '<CR>', function() require('aws-nvim').toggle_node() end, opts)
    vim.keymap.set('n', 'o', function() require('aws-nvim').open_details() end, opts)
    vim.keymap.set('n', 'r', function() require('aws-nvim').refresh_node() end, opts)
    vim.keymap.set('n', 'f', function() require('aws-nvim').prompt_filter() end, opts)
    vim.keymap.set('n', 'a', function() require('aws-nvim').show_actions() end, opts)
    vim.keymap.set('n', 'l', function() require('aws-nvim').view_logs() end, opts)
    vim.keymap.set('n', 'c', function() require('aws-nvim').copy_resource_info() end, opts)
    vim.keymap.set('n', 'q', ':q<CR>', opts)
  end,
}) 