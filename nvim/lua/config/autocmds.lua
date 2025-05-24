-- Autocommands and custom functions

-- Create command to wipe unnamed buffers
vim.api.nvim_create_user_command('WipeNoNameBuffers', function()
  local bufinfos = vim.fn.getbufinfo()
  for _, bufinfo in ipairs(bufinfos) do
    if bufinfo.name == "" then
      vim.cmd("bw " .. bufinfo.bufnr)
    end
  end
end, {})

-- Git branch checkout function for FZF
local function git_checkout_branch(branch)
  local name = vim.split(vim.split(vim.trim(branch), "", true)[1], "/", true)
  name = name[#name]
  vim.cmd("G checkout " .. name)
end

-- Create Gbranch command
vim.api.nvim_create_user_command('Gbranch', function()
  vim.fn['fzf#run'](vim.fn['fzf#wrap']({
    source = 'git branch -avv --color',
    sink = git_checkout_branch,
    options = '--ansi --nth=1'
  }))
end, { bang = true })

-- VIMGREPCURRWORD command
vim.api.nvim_create_user_command('VIMGREPCURRWORD', function()
  vim.cmd('grep! ' .. vim.fn.expand('<cword>'))
end, {})

-- BuildMake command
vim.api.nvim_create_user_command('BuildMake', function()
  vim.cmd('Make -j -C build')
end, {})

-- RunTests command
vim.api.nvim_create_user_command('RunTests', function()
  if vim.fn.fnamemodify(vim.fn.getcwd(), ':t') ~= "build" then
    vim.cmd('cd build')
  end
  vim.cmd('Dispatch ctest -VV')
  vim.cmd('cd ..')
end, {}) 