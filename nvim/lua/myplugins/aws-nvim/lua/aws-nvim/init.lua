-- aws-nvim main module
local M = {}

-- Require submodules
local config = require('aws-nvim.config')
local aws = require('aws-nvim.aws')
local cache = require('aws-nvim.cache')

-- Setup function for user configuration
function M.setup(opts)
  -- Pass options to config module
  config.setup(opts)
  
  -- Load saved filters
  config.state.saved_filters = cache.load_filters()
end

-- Open the AWS resource explorer
function M.open_explorer()
  -- Create buffer if it doesn't exist
  if not config.state.buffer or not vim.api.nvim_buf_is_valid(config.state.buffer) then
    config.state.buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(config.state.buffer, 'filetype', 'aws-nvim')
    vim.api.nvim_buf_set_option(config.state.buffer, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(config.state.buffer, 'modifiable', false)
    vim.api.nvim_buf_set_name(config.state.buffer, 'AWS-Nvim')
  end

  -- Create window if it doesn't exist or is not valid
  if not config.state.window or not vim.api.nvim_win_is_valid(config.state.window) then
    -- Determine split command based on configuration
    local split_cmd = config.options.split_direction == 'right' and 'vsplit' or 'split'
    vim.cmd(split_cmd)
    
    config.state.window = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(config.state.window, config.state.buffer)
    
    -- Set window options
    vim.api.nvim_win_set_option(config.state.window, 'number', false)
    vim.api.nvim_win_set_option(config.state.window, 'relativenumber', false)
    vim.api.nvim_win_set_option(config.state.window, 'signcolumn', 'no')
    
    -- Set window width/height based on configuration
    if config.options.split_direction == 'right' then
      vim.api.nvim_win_set_width(config.state.window, config.options.width)
    else
      vim.api.nvim_win_set_height(config.state.window, config.options.height)
    end
  end

  -- Load initial stacks if tree is empty
  if vim.tbl_isempty(config.state.tree) then
    M.load_stacks()
  else
    M.render_tree()
  end
end

-- Open a specific stack and expand it
function M.open_stack(stack_name)
  if not stack_name or stack_name == '' then
    -- Open stack picker
    M.open_explorer()
    return
  end

  -- Open explorer and then expand the stack
  M.open_explorer()
  
  -- Find stack in tree and expand it
  for i, node in ipairs(config.state.tree) do
    if node.name == stack_name then
      node.expanded = true
      M.load_stack_services(node)
      break
    end
  end
  
  M.render_tree()
end

-- Load available CloudFormation stacks
function M.load_stacks()
  -- Clear existing tree
  config.state.tree = {}
  
  -- Use cached data if available and not expired
  local cache_key = config.create_cache_key('stacks')
  local cached = cache.get(cache_key, 'stack')
  
  if cached then
    config.state.tree = cached
    M.render_tree()
    return
  end
  
  -- Update buffer to show loading message
  M.update_buffer({'Loading stacks...', 'Please wait...'})
  
  -- Call AWS API to get stacks
  aws.list_stacks(config.options.region, config.options.profile, function(err, stacks)
    if err then
      M.update_buffer({'Error loading stacks:', err, '', 'Press r to retry.'})
      return
    end
    
    -- Store in tree and cache
    config.state.tree = stacks
    cache.set(cache_key, stacks, 'stack')
    
    -- Render the tree
    M.render_tree()
  end)
end

-- Load services for a specific stack
function M.load_stack_services(stack_node)
  -- Skip if already loaded
  if #stack_node.children > 0 then
    return
  end
  
  -- Use cached data if available
  local cache_key = config.create_cache_key('services', nil, stack_node.id)
  local cached = cache.get(cache_key, 'service')
  
  if cached then
    stack_node.children = cached
    M.render_tree()
    return
  end
  
  -- Update the stack node to show it's loading
  stack_node.loading = true
  M.render_tree()
  
  -- Call AWS API to get services
  aws.list_stack_services(
    stack_node.id, 
    stack_node.name, 
    config.options.region, 
    config.options.profile, 
    function(err, services)
      -- Clear loading state
      stack_node.loading = false
      
      if err then
        vim.api.nvim_echo({{"Error loading services: " .. err, "ErrorMsg"}}, false, {})
        M.render_tree()
        return
      end
      
      -- Store in node and cache
      stack_node.children = services
      cache.set(cache_key, services, 'service')
      
      -- Render the tree
      M.render_tree()
    end
  )
end

-- Load tasks for a specific service
function M.load_service_tasks(service_node)
  -- Skip if already loaded
  if #service_node.children > 0 then
    return
  end
  
  -- Use cached data if available
  local cache_key = config.create_cache_key('tasks', nil, service_node.id)
  local cached = cache.get(cache_key, 'task')
  
  if cached then
    service_node.children = cached
    M.render_tree()
    return
  end
  
  -- Update the service node to show it's loading
  service_node.loading = true
  M.render_tree()
  
  -- Call AWS API to get tasks
  aws.list_service_tasks(
    service_node.id,
    service_node.cluster,
    service_node.name,
    config.options.region,
    config.options.profile,
    function(err, tasks)
      -- Clear loading state
      service_node.loading = false
      
      if err then
        vim.api.nvim_echo({{"Error loading tasks: " .. err, "ErrorMsg"}}, false, {})
        M.render_tree()
        return
      end
      
      -- Store in node and cache
      service_node.children = tasks
      cache.set(cache_key, tasks, 'task')
      
      -- Render the tree
      M.render_tree()
    end
  )
end

-- Load containers for a specific task
function M.load_task_containers(task_node)
  -- Skip if already loaded
  if #task_node.children > 0 then
    return
  end
  
  -- Use cached data if available
  local cache_key = config.create_cache_key('containers', nil, task_node.id)
  local cached = cache.get(cache_key, 'container')
  
  if cached then
    task_node.children = cached
    M.render_tree()
    return
  end
  
  -- Update the task node to show it's loading
  task_node.loading = true
  M.render_tree()
  
  -- Call AWS API to get containers
  aws.list_task_containers(
    task_node.id,
    task_node.cluster,
    config.options.region,
    config.options.profile,
    function(err, containers)
      -- Clear loading state
      task_node.loading = false
      
      if err then
        vim.api.nvim_echo({{"Error loading containers: " .. err, "ErrorMsg"}}, false, {})
        M.render_tree()
        return
      end
      
      -- Store in node and cache
      task_node.children = containers
      cache.set(cache_key, containers, 'container')
      
      -- Render the tree
      M.render_tree()
    end
  )
end

-- Toggle expand/collapse of a node
function M.toggle_node()
  -- Get the line under the cursor
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local node = M.get_node_at_line(line)
  
  if not node then
    return
  end
  
  -- Toggle expanded state
  node.expanded = not node.expanded
  
  -- Load children if expanded and has children
  if node.expanded and node.has_children then
    if node.type == 'stack' then
      M.load_stack_services(node)
    elseif node.type == 'service' then
      M.load_service_tasks(node)
    elseif node.type == 'task' then
      M.load_task_containers(node)
    end
  end
  
  M.render_tree()
end

-- Get node at specific line in the tree view
function M.get_node_at_line(line)
  -- Build a flat list of visible nodes
  local visible_nodes = {}
  
  local function traverse(nodes, depth)
    for _, node in ipairs(nodes) do
      table.insert(visible_nodes, {node = node, depth = depth})
      if node.expanded and #node.children > 0 then
        traverse(node.children, depth + 1)
      end
    end
  end
  
  traverse(config.state.tree, 0)
  
  -- Check if line is within range
  if line > 0 and line <= #visible_nodes then
    return visible_nodes[line].node
  end
  
  return nil
end

-- Render the tree to the buffer
function M.render_tree()
  if not config.state.buffer or not vim.api.nvim_buf_is_valid(config.state.buffer) then
    return
  end
  
  -- Save current cursor position
  local cursor_pos = nil
  if config.state.window and vim.api.nvim_win_is_valid(config.state.window) then
    cursor_pos = vim.api.nvim_win_get_cursor(config.state.window)
  end
  
  -- Generate lines to display
  local lines = {}
  
  -- Handle empty tree
  if vim.tbl_isempty(config.state.tree) then
    table.insert(lines, "No AWS stacks found")
    table.insert(lines, "Press 'r' to refresh")
    M.update_buffer(lines)
    return
  end
  
  local function render_node(node, depth, is_last)
    -- Skip if filtered out (only apply filter to stack nodes)
    if config.state.filter and node.type == 'stack' and not string.find(string.lower(node.name), string.lower(config.state.filter)) then
      return false -- Skip this stack
    end
    
    -- Create indentation prefix
    local prefix = string.rep("  ", depth)
    
    -- Add appropriate icon based on node type and state
    local icon = config.get_node_icon(node)
    
    -- Create status indicator
    local status_indicator = ""
    if node.status then
      status_indicator = " " .. config.get_status_icon(node.status, node.health)
    end
    
    -- Create line text
    local line = prefix .. icon .. " " .. node.name
    
    -- Add type-specific information
    if node.type == 'service' then
      -- Add running/desired count if available
      if node.running_count and node.desired_count then
        line = line .. " [" .. node.running_count .. "/" .. node.desired_count .. "]"
      else
        line = line .. " [" .. node.cluster .. "]"
      end
    elseif node.type == 'container' then
      -- Truncate image name if too long
      local image = node.image
      if #image > 30 then
        image = string.sub(image, 1, 27) .. "..."
      end
      line = line .. " [" .. image .. "]"
    end
    
    -- Add status
    line = line .. status_indicator
    
    table.insert(lines, line)
    
    -- Node is visible
    local node_visible = true
    
    -- Render children if expanded
    if node.expanded and #node.children > 0 then
      for i, child in ipairs(node.children) do
        local child_visible = render_node(child, depth + 1, i == #node.children)
        node_visible = node_visible or child_visible
      end
    end
    
    return node_visible
  end
  
  -- Render each top-level node
  for i, node in ipairs(config.state.tree) do
    render_node(node, 0, i == #config.state.tree)
  end
  
  -- Update the buffer with the rendered lines
  M.update_buffer(lines)
  
  -- Restore cursor position if possible
  if cursor_pos and config.state.window and vim.api.nvim_win_is_valid(config.state.window) then
    -- Make sure cursor position is within bounds
    local line_count = vim.api.nvim_buf_line_count(config.state.buffer)
    if cursor_pos[1] > line_count then
      cursor_pos[1] = line_count
    end
    vim.api.nvim_win_set_cursor(config.state.window, cursor_pos)
  end
end

-- Update the buffer content
function M.update_buffer(lines)
  -- Ensure buffer exists and is valid
  if not config.state.buffer or not vim.api.nvim_buf_is_valid(config.state.buffer) then
    return
  end
  
  -- Make buffer modifiable
  vim.api.nvim_buf_set_option(config.state.buffer, 'modifiable', true)
  
  -- Clear buffer
  vim.api.nvim_buf_set_lines(config.state.buffer, 0, -1, false, {})
  
  -- Add new lines
  vim.api.nvim_buf_set_lines(config.state.buffer, 0, -1, false, lines)
  
  -- Make buffer non-modifiable again
  vim.api.nvim_buf_set_option(config.state.buffer, 'modifiable', false)
end

-- Refresh the current view
function M.refresh()
  -- Clear cache for the current view
  cache.clear()
  
  -- Reload stacks
  M.load_stacks()
end

-- Refresh a specific node
function M.refresh_node()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local node = M.get_node_at_line(line)
  
  if not node then
    return
  end
  
  -- Clear cache for this node
  local cache_key = ''
  if node.type == 'stack' then
    cache_key = config.create_cache_key('services', nil, node.id)
    node.children = {}
    if node.expanded then
      M.load_stack_services(node)
    end
  elseif node.type == 'service' then
    cache_key = config.create_cache_key('tasks', nil, node.id)
    node.children = {}
    if node.expanded then
      M.load_service_tasks(node)
    end
  elseif node.type == 'task' then
    cache_key = config.create_cache_key('containers', nil, node.id)
    node.children = {}
    if node.expanded then
      M.load_task_containers(node)
    end
  else
    -- For container nodes or the root level, refresh the parent
    if node.parent then
      M.refresh_node(node.parent)
    else
      M.refresh()
    end
    return
  end
  
  -- Invalidate cache
  cache.invalidate(cache_key)
  
  -- Render the updated tree
  M.render_tree()
end

-- Filter the tree
function M.filter(pattern)
  -- If pattern is not provided, show the filter management UI
  if not pattern or pattern == "" then
    M.show_filter_manager()
    return
  end
  
  config.state.filter = pattern
  M.render_tree()
end

-- Show filter management UI
function M.show_filter_manager()
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
  vim.keymap.set('n', '<CR>', function() M.filter_manager_select() end, opts)
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
function M.filter_manager_select()
  local state = config.state.filter_manager
  if not state or #config.state.saved_filters == 0 then return end
  
  -- Get selected filter
  local selected_filter = config.state.saved_filters[state.selected_index]
  
  -- Close filter manager
  M.filter_manager_close()
  
  -- Apply filter
  config.state.filter = selected_filter
  M.render_tree()
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

-- Set AWS profile
function M.set_profile(profile)
  -- If profile is not provided, show the profile picker
  if not profile or profile == "" then
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
          
          -- Save preferences
          config.save_preferences()
          
          -- Clear cache when changing profile
          cache.clear()
          
          -- Reload stacks
          M.load_stacks()
          
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
    return
  end
  
  -- If profile is provided directly, set it
  config.options.profile = profile
  
  -- Save preferences
  config.save_preferences()
  
  -- Clear cache when changing profile
  cache.clear()
  
  -- Reload stacks
  M.load_stacks()
end

-- Set AWS region
function M.set_region(region)
  -- If region is not provided, show a picker with all available regions
  if not region or region == "" then
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
        
        -- Save preferences
        config.save_preferences()
        
        -- Clear cache when changing region
        cache.clear()
        M.load_stacks()
        -- Show confirmation message
        vim.api.nvim_echo({{"Region changed to " .. choice.region, "Normal"}}, false, {})
      end
    end)
    return
  end
  
  -- If region is provided directly, set it
  config.options.region = region
  
  -- Save preferences
  config.save_preferences()
  
  -- Clear cache when changing region
  cache.clear()
  M.load_stacks()
end

-- Open details for a node
function M.open_details()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local node = M.get_node_at_line(line)
  
  if not node then
    return
  end
  
  -- Create a details buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  
  -- Generate details content
  local lines = {
    "Details for " .. node.name,
    "-------------" .. string.rep("-", #node.name),
    "Type: " .. node.type,
    "ID: " .. node.id,
  }
  
  -- Add type-specific details
  if node.type == 'stack' then
    table.insert(lines, "Status: " .. node.status)
    table.insert(lines, "")
    table.insert(lines, "Console URL: https://console.aws.amazon.com/cloudformation/home?region=" .. 
                  config.options.region .. "#/stacks/stackinfo?stackId=" .. node.id)
  elseif node.type == 'service' then
    table.insert(lines, "Cluster: " .. node.cluster)
    table.insert(lines, "Status: " .. node.status)
    if node.running_count and node.desired_count then
      table.insert(lines, "Tasks: " .. node.running_count .. "/" .. node.desired_count .. " running")
    end
    table.insert(lines, "")
    table.insert(lines, "Console URL: https://console.aws.amazon.com/ecs/home?region=" .. 
                  config.options.region .. "#/clusters/" .. node.cluster .. "/services/" .. node.name .. "/details")
  elseif node.type == 'task' then
    table.insert(lines, "Status: " .. node.status)
    table.insert(lines, "Health: " .. node.health)
    table.insert(lines, "Task Definition: " .. node.task_definition)
    table.insert(lines, "")
    table.insert(lines, "Console URL: https://console.aws.amazon.com/ecs/home?region=" .. 
                  config.options.region .. "#/clusters/" .. node.cluster .. "/tasks/" .. node.id .. "/details")
  elseif node.type == 'container' then
    table.insert(lines, "Image: " .. node.image)
    table.insert(lines, "Status: " .. node.status)
    table.insert(lines, "Health: " .. node.health)
    table.insert(lines, "")
    table.insert(lines, "Logs: " .. node.logs)
    table.insert(lines, "")
    table.insert(lines, "Actions:")
    table.insert(lines, "1. View logs: 'l' key")
    table.insert(lines, "2. SSH into container: 'a' key, then select 'SSH Into Container'")
  end
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Open in a split
  vim.cmd('vsplit')
  vim.api.nvim_win_set_buf(0, buf)
end

-- View logs for a container
function M.view_logs()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local node = M.get_node_at_line(line)
  
  if not node or node.type ~= 'container' then
    vim.api.nvim_echo({{"Must select a container node", "WarningMsg"}}, false, {})
    return
  end
  
  -- Check if logs path is available
  if not node.logs or node.logs == "" then
    vim.api.nvim_echo({{"No logs configuration found for this container", "WarningMsg"}}, false, {})
    return
  end
  
  -- Open terminal with CloudWatch logs command
  local cmd = string.format(
    "aws logs tail %s --region %s --follow",
    node.logs,
    config.options.region
  )
  
  -- Add profile if set
  if config.options.profile and config.options.profile ~= '' then
    cmd = cmd .. " --profile " .. config.options.profile
  end
  
  -- Open in a new split
  vim.cmd('split')
  vim.cmd('terminal ' .. cmd)
end

-- Show available actions for a node
function M.show_actions()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local node = M.get_node_at_line(line)
  
  if not node then
    return
  end
  
  local actions = {}
  
  -- Define actions based on node type
  if node.type == 'stack' then
    actions = {
      { name = "View Stack Events", action = "stack_events" },
      { name = "View Resources", action = "stack_resources" },
      { name = "Update Stack", action = "update_stack" },
      { name = "Delete Stack", action = "delete_stack" }
    }
  elseif node.type == 'service' then
    actions = {
      { name = "Update Service", action = "update_service" },
      { name = "Scale Service", action = "scale_service" },
      { name = "Restart Service", action = "restart_service" }
    }
  elseif node.type == 'task' then
    actions = {
      { name = "Stop Task", action = "stop_task" },
      { name = "View Task Definition", action = "view_task_definition" }
    }
  elseif node.type == 'container' then
    actions = {
      { name = "View Logs", action = "view_logs" },
      { name = "SSH Into Container", action = "ssh_container" },
      { name = "Restart Container", action = "restart_container" }
    }
  end
  
  -- Create a popup menu for actions
  if #actions == 0 then
    vim.api.nvim_echo({{"No actions available for this node", "WarningMsg"}}, false, {})
    return
  end
  
  -- Convert actions to format for vim.ui.select
  local choices = {}
  for _, action in ipairs(actions) do
    table.insert(choices, action.name)
  end
  
  -- Show selection menu
  vim.ui.select(choices, {
    prompt = "Select action for " .. node.name,
    format_item = function(item)
      return item
    end
  }, function(choice)
    if not choice then
      return
    end
    
    -- Find the selected action
    for _, action in ipairs(actions) do
      if action.name == choice then
        -- Execute the action
        if action.action == "view_logs" then
          M.view_logs()
        elseif action.action == "ssh_container" then
          M.ssh_container(node)
        else
          -- For unimplemented actions
          vim.api.nvim_echo({{
            "Action '" .. action.action .. "' on node '" .. node.name .. "' is not yet implemented", 
            "WarningMsg"
          }}, false, {})
        end
        break
      end
    end
  end)
end

-- SSH into container
function M.ssh_container(node)
  if not node or node.type ~= 'container' then
    vim.api.nvim_echo({{"Must select a container node", "WarningMsg"}}, false, {})
    return
  end
  
  -- Show loading message
  vim.api.nvim_echo({{"Getting SSH command for container...", "Normal"}}, false, {})
  
  -- Get SSM command for container
  aws.get_container_ssh_command(
    node.id,
    node.task_id,
    node.cluster,
    config.options.region,
    config.options.profile,
    function(err, command)
      if err then
        vim.api.nvim_echo({{"Error getting SSH command: " .. err, "ErrorMsg"}}, false, {})
        return
      end
      
      -- Copy command to clipboard
      vim.fn.setreg('+', command)
      
      -- Show the command
      vim.api.nvim_echo({
        {"SSH command copied to clipboard: ", "Normal"},
        {command, "String"}
      }, false, {})
    end
  )
end

-- Copy resource info to clipboard
function M.copy_resource_info()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local node = M.get_node_at_line(line)
  
  if not node then
    return
  end
  
  -- Define what to copy based on node type
  local copy_text = ""
  
  if node.type == 'stack' then
    copy_text = "https://console.aws.amazon.com/cloudformation/home?region=" .. 
                config.options.region .. "#/stacks/stackinfo?stackId=" .. node.id
  elseif node.type == 'service' then
    copy_text = "https://console.aws.amazon.com/ecs/home?region=" .. 
                config.options.region .. "#/clusters/" .. node.cluster .. "/services/" .. node.name .. "/details"
  elseif node.type == 'task' then
    copy_text = "https://console.aws.amazon.com/ecs/home?region=" .. 
                config.options.region .. "#/clusters/" .. node.cluster .. "/tasks/" .. node.id .. "/details"
  elseif node.type == 'container' then
    copy_text = node.logs
  end
  
  -- Copy to clipboard
  vim.fn.setreg('+', copy_text)
  vim.api.nvim_echo({{"Copied to clipboard", "Normal"}}, false, {})
end

return M 