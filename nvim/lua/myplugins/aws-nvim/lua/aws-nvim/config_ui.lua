-- Configuration UI functions for aws-nvim
local M = {}

local config = require('aws-nvim.config')
local aws = require('aws-nvim.aws')
local cache = require('aws-nvim.cache')

-- Show filter management UI
function M.show_filter_manager(main_module)
  -- Create a new buffer for the filter manager
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'aws-nvim-filters')
  
  -- Open in a floating window
  local width = 60
  local height = math.min(15, #config.state.saved_filters + 5)
  
  local ui = vim.api.nvim_list_uis()[1]
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = 'minimal',
    border = 'rounded'
  }
  
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
  
  -- Store buffer and window IDs for later use
  config.state.filter_manager = {
    buffer = buf,
    window = win,
    selected_index = 1
  }
  
  -- Render filter list
  M.render_filter_manager()
  
  -- Set up keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set('n', 'j', function() M.filter_manager_move_selection(1) end, opts)
  vim.keymap.set('n', 'k', function() M.filter_manager_move_selection(-1) end, opts)
  vim.keymap.set('n', '<C-j>', function() M.filter_manager_move_filter(1) end, opts)
  vim.keymap.set('n', '<C-k>', function() M.filter_manager_move_filter(-1) end, opts)
  vim.keymap.set('n', '<CR>', function() M.filter_manager_select(main_module) end, opts)
  vim.keymap.set('n', 'a', function() M.filter_manager_add() end, opts)
  vim.keymap.set('n', 'x', function() M.filter_manager_delete() end, opts)
  vim.keymap.set('n', 'q', function() M.filter_manager_close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.filter_manager_close() end, opts)
  
  -- Set up autocommands to clean up on window close
  local group = vim.api.nvim_create_augroup('aws_nvim_filter_manager', { clear = true })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    pattern = tostring(win),
    callback = function()
      if config.state.filter_manager and config.state.filter_manager.buffer then
        vim.api.nvim_buf_delete(config.state.filter_manager.buffer, { force = true })
        config.state.filter_manager = nil
      end
    end,
    once = true
  })
end

-- Render the filter manager UI
function M.render_filter_manager()
  local state = config.state.filter_manager
  if not state or not state.buffer or not vim.api.nvim_buf_is_valid(state.buffer) then
    return
  end
  
  local lines = {
    "AWS Stack Filters",
    "================="
  }
  
  -- Add instructions
  table.insert(lines, "")
  table.insert(lines, "j/k: Navigate  ⏎: Select  a: Add  x: Delete  Ctrl-j/k: Move  q: Close")
  table.insert(lines, "")
  
  -- Add filters
  if #config.state.saved_filters == 0 then
    table.insert(lines, "No saved filters. Press 'a' to add one.")
  else
    for i, filter in ipairs(config.state.saved_filters) do
      local prefix = (i == state.selected_index) and "→ " or "  "
      table.insert(lines, prefix .. filter)
    end
  end
  
  -- Set buffer content
  vim.api.nvim_buf_set_option(state.buffer, 'modifiable', true)
  vim.api.nvim_buf_set_lines(state.buffer, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buffer, 'modifiable', false)
  
  -- Set cursor position
  if #config.state.saved_filters > 0 then
    vim.api.nvim_win_set_cursor(state.window, {5 + state.selected_index, 2})
  end
end

-- Move the selection in the filter manager
function M.filter_manager_move_selection(direction)
  local state = config.state.filter_manager
  if not state then return end
  
  local new_index = state.selected_index + direction
  if new_index >= 1 and new_index <= #config.state.saved_filters then
    state.selected_index = new_index
    M.render_filter_manager()
  end
end

-- Move a filter up or down in the list
function M.filter_manager_move_filter(direction)
  local state = config.state.filter_manager
  if not state or #config.state.saved_filters == 0 then return end
  
  local curr_index = state.selected_index
  local new_index = curr_index + direction
  
  if new_index >= 1 and new_index <= #config.state.saved_filters then
    -- Swap filters
    local temp = config.state.saved_filters[curr_index]
    config.state.saved_filters[curr_index] = config.state.saved_filters[new_index]
    config.state.saved_filters[new_index] = temp
    
    -- Update selection
    state.selected_index = new_index
    
    -- Save changes
    cache.save_filters(config.state.saved_filters)
    
    -- Render UI
    M.render_filter_manager()
  end
end

-- Select a filter and apply it
function M.filter_manager_select(main_module)
  local state = config.state.filter_manager
  if not state or #config.state.saved_filters == 0 then return end
  
  -- Get selected filter
  local selected_filter = config.state.saved_filters[state.selected_index]
  
  -- Close filter manager
  M.filter_manager_close()
  
  -- Apply filter
  config.state.filter = selected_filter
  main_module.render_tree()
end

-- Add a new filter
function M.filter_manager_add()
  vim.ui.input({
    prompt = "Enter new filter: "
  }, function(input)
    if input and input ~= "" then
      -- Add to filters
      table.insert(config.state.saved_filters, input)
      
      -- Save changes
      cache.save_filters(config.state.saved_filters)
      
      -- Update UI
      if config.state.filter_manager then
        config.state.filter_manager.selected_index = #config.state.saved_filters
        M.render_filter_manager()
      end
    end
  end)
end

-- Delete the selected filter
function M.filter_manager_delete()
  local state = config.state.filter_manager
  if not state or #config.state.saved_filters == 0 then return end
  
  -- Remove the filter
  table.remove(config.state.saved_filters, state.selected_index)
  
  -- Save changes
  cache.save_filters(config.state.saved_filters)
  
  -- Update selection index
  if state.selected_index > #config.state.saved_filters and #config.state.saved_filters > 0 then
    state.selected_index = #config.state.saved_filters
  end
  
  -- Update UI
  M.render_filter_manager()
end

-- Close the filter manager
function M.filter_manager_close()
  local state = config.state.filter_manager
  if not state then return end
  
  if state.window and vim.api.nvim_win_is_valid(state.window) then
    vim.api.nvim_win_close(state.window, true)
  end
  
  config.state.filter_manager = nil
end

-- Set AWS profile with UI picker
function M.set_profile_with_picker(main_module, profile)
  -- If profile is provided directly, set it
  if profile and profile ~= "" then
    config.options.profile = profile
    config.save_preferences()
    cache.clear()
    main_module.load_stacks()
    return
  end
  
  -- Show loading message
  vim.api.nvim_echo({{"Loading AWS profiles...", "Normal"}}, false, {})
  
  -- Get available profiles
  aws.get_available_profiles(function(profiles)
    -- Create a profile selection UI
    if #profiles == 0 then
      vim.api.nvim_echo({{"No AWS profiles found", "WarningMsg"}}, false, {})
      return
    end
    
    -- Create a floating window for profile selection
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'aws-nvim-profiles')
    
    -- Open in a floating window
    local width = 60
    local height = math.min(15, #profiles + 3)
    
    local ui = vim.api.nvim_list_uis()[1]
    local win_opts = {
      relative = 'editor',
      width = width,
      height = height,
      col = math.floor((ui.width - width) / 2),
      row = math.floor((ui.height - height) / 2),
      style = 'minimal',
      border = 'rounded'
    }
    
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:FloatBorder')
    
    -- Generate content
    local lines = {
      "AWS Profiles",
      "==========="
    }
    
    -- Add instructions
    table.insert(lines, "")
    
    -- Find current profile
    local current_profile = config.options.profile
    if current_profile == "" then
      current_profile = "default"
    end
    
    -- Add profiles
    local selected_index = 1
    for i, p in ipairs(profiles) do
      local prefix = ""
      if p == current_profile then
        prefix = "→ "
        selected_index = i
      else
        prefix = "  "
      end
      table.insert(lines, prefix .. p)
    end
    
    -- Set buffer content
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    
    -- Set cursor position
    vim.api.nvim_win_set_cursor(win, {3 + selected_index, 0})
    
    -- Set up keymaps
    local opts = { noremap = true, silent = true, buffer = buf }
    
    -- Navigation
    vim.keymap.set('n', 'j', function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[1] < 3 + #profiles then
        vim.api.nvim_win_set_cursor(win, {cursor[1] + 1, cursor[2]})
      end
    end, opts)
    
    vim.keymap.set('n', 'k', function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[1] > 4 then
        vim.api.nvim_win_set_cursor(win, {cursor[1] - 1, cursor[2]})
      end
    end, opts)
    
    -- Selection
    vim.keymap.set('n', '<CR>', function()
      local cursor = vim.api.nvim_win_get_cursor(win)
      local index = cursor[1] - 3
      if index >= 1 and index <= #profiles then
        local selected = profiles[index]
        
        -- Close window
        vim.api.nvim_win_close(win, true)
        
        -- Apply profile
        config.options.profile = selected
        config.save_preferences()
        cache.clear()
        main_module.load_stacks()
        
        -- Show confirmation
        vim.api.nvim_echo({{"Profile changed to " .. selected, "Normal"}}, false, {})
      end
    end, opts)
    
    -- Close
    vim.keymap.set('n', 'q', function()
      vim.api.nvim_win_close(win, true)
    end, opts)
    
    vim.keymap.set('n', '<Esc>', function()
      vim.api.nvim_win_close(win, true)
    end, opts)
    
    -- Set up autocommands to clean up on window close
    local group = vim.api.nvim_create_augroup('aws_nvim_profile_picker', { clear = true })
    vim.api.nvim_create_autocmd('WinClosed', {
      group = group,
      pattern = tostring(win),
      callback = function()
        vim.api.nvim_buf_delete(buf, { force = true })
      end,
      once = true
    })
  end)
end

-- Set AWS region with UI picker
function M.set_region_with_picker(main_module, region)
  -- If region is provided directly, set it
  if region and region ~= "" then
    config.options.region = region
    config.save_preferences()
    cache.clear()
    main_module.load_stacks()
    return
  end
  
  -- List of all AWS regions
  local regions = {
    "us-east-1",      -- US East (N. Virginia)
    "us-east-2",      -- US East (Ohio)
    "us-west-1",      -- US West (N. California)
    "us-west-2",      -- US West (Oregon)
    "af-south-1",     -- Africa (Cape Town)
    "ap-east-1",      -- Asia Pacific (Hong Kong)
    "ap-south-1",     -- Asia Pacific (Mumbai)
    "ap-northeast-1", -- Asia Pacific (Tokyo)
    "ap-northeast-2", -- Asia Pacific (Seoul)
    "ap-northeast-3", -- Asia Pacific (Osaka)
    "ap-southeast-1", -- Asia Pacific (Singapore)
    "ap-southeast-2", -- Asia Pacific (Sydney)
    "ap-southeast-3", -- Asia Pacific (Jakarta)
    "ca-central-1",   -- Canada (Central)
    "eu-central-1",   -- Europe (Frankfurt)
    "eu-west-1",      -- Europe (Ireland)
    "eu-west-2",      -- Europe (London)
    "eu-west-3",      -- Europe (Paris)
    "eu-north-1",     -- Europe (Stockholm)
    "eu-south-1",     -- Europe (Milan)
    "me-south-1",     -- Middle East (Bahrain)
    "sa-east-1"       -- South America (São Paulo)
  }
  
  -- Format regions with descriptions for the picker
  local choices = {}
  for _, r in ipairs(regions) do
    local description = r
    if r == "us-east-1" then
      description = r .. " (US East, N. Virginia)"
    elseif r == "us-east-2" then
      description = r .. " (US East, Ohio)"
    elseif r == "us-west-1" then
      description = r .. " (US West, N. California)"
    elseif r == "us-west-2" then
      description = r .. " (US West, Oregon)"
    elseif r == "eu-west-1" then
      description = r .. " (Europe, Ireland)"
    elseif r == "eu-central-1" then
      description = r .. " (Europe, Frankfurt)"
    elseif r == "ap-northeast-1" then
      description = r .. " (Asia Pacific, Tokyo)"
    elseif r == "ap-southeast-1" then
      description = r .. " (Asia Pacific, Singapore)"
    elseif r == "ap-southeast-2" then
      description = r .. " (Asia Pacific, Sydney)"
    end
    table.insert(choices, { region = r, description = description })
  end
  
  -- Show region selection menu
  vim.ui.select(choices, {
    prompt = "Select AWS Region",
    format_item = function(item)
      return item.description
    end
  }, function(choice)
    if choice then
      -- Apply the selected region
      config.options.region = choice.region
      config.save_preferences()
      cache.clear()
      main_module.load_stacks()
      -- Show confirmation message
      vim.api.nvim_echo({{"Region changed to " .. choice.region, "Normal"}}, false, {})
    end
  end)
end

return M 