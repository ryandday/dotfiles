-- aws-nvim main module
local M = {}

-- Require submodules
local config = require('aws-nvim.config')
local aws = require('aws-nvim.aws')
local cache = require('aws-nvim.cache')
local config_ui = require('aws-nvim.config_ui')
local stack_view_ui = require('aws-nvim.stack_view_ui')

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
  stack_view_ui.update_buffer({'Loading stacks...', 'Please wait...'})
  
  -- Call AWS API to get stacks
  aws.list_stacks(config.options.region, config.options.profile, function(err, stacks)
    if err then
      stack_view_ui.update_buffer({'Error loading stacks:', err, '', 'Press r to retry.'})
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
  local node = stack_view_ui.get_node_at_line(line)
  
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

-- Delegate to stack_view_ui
function M.render_tree()
  stack_view_ui.render_tree()
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
  local node = stack_view_ui.get_node_at_line(line)
  
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
    config_ui.show_filter_manager(M)
    return
  end
  
  config.state.filter = pattern
  M.render_tree()
end

-- Set AWS profile
function M.set_profile(profile)
  config_ui.set_profile_with_picker(M, profile)
end

-- Set AWS region
function M.set_region(region)
  config_ui.set_region_with_picker(M, region)
end

-- Delegate to stack_view_ui
function M.open_details()
  stack_view_ui.open_details()
end

-- Delegate to stack_view_ui
function M.view_logs()
  stack_view_ui.view_logs()
end

-- Delegate to stack_view_ui
function M.show_actions()
  stack_view_ui.show_actions()
end

-- Delegate to stack_view_ui
function M.copy_resource_info()
  stack_view_ui.copy_resource_info()
end

-- Clear cache and reload
function M.clear_cache()
  -- Clear all cached data
  cache.clear()
  
  -- Show confirmation message
  vim.api.nvim_echo({{"AWS cache cleared", "Normal"}}, false, {})
  
  -- If explorer is open, reload stacks
  if config.state.buffer and vim.api.nvim_buf_is_valid(config.state.buffer) then
    M.load_stacks()
  end
end

return M 