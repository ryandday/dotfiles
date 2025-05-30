-- Stack view UI functions for aws-nvim
local M = {}

local config = require('aws-nvim.config')
local aws = require('aws-nvim.aws')

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