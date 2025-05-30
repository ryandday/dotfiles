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
    -- Skip if filtered out
    if config.state.filter and not string.find(string.lower(node.name), string.lower(config.state.filter)) then
      -- If node doesn't match filter, check if any children match
      if node.expanded and #node.children > 0 then
        local any_child_visible = false
        for _, child in ipairs(node.children) do
          if string.find(string.lower(child.name), string.lower(config.state.filter)) then
            any_child_visible = true
            break
          end
        end
        
        if not any_child_visible then
          return false -- Skip this node and its children
        end
      else
        return false -- Skip this node
      end
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
  config.state.filter = pattern
  M.render_tree()
end

-- Prompt for filter pattern
function M.prompt_filter()
  vim.ui.input({
    prompt = "Filter: ",
    default = config.state.filter or ""
  }, function(input)
    if input then
      M.filter(input)
    end
  end)
end

-- Set AWS profile
function M.set_profile(profile)
  config.options.profile = profile
  -- Clear cache when changing profile
  cache.clear()
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