-- config.lua - Configuration module for AWS-Nvim
local M = {}

-- Default configuration
M.options = {
  -- AWS settings
  region = 'us-east-1',
  profile = '',
  
  -- Cache settings
  cache_ttl = {
    stack = 600,    -- 10 minutes
    service = 300,  -- 5 minutes
    task = 120,     -- 2 minutes
    container = 60  -- 1 minute
  },
  
  -- UI settings
  split_direction = 'right',
  width = 40,
  height = 20,
  
  -- Visual indicators
  icons = {
    expanded = '▼',
    collapsed = '▶',
    leaf = ' ',
    loading = '⟳',
    status = {
      ok = '✓',
      warning = '⚠',
      error = '✗',
      unknown = '?'
    }
  }
}

-- Internal state
M.state = {
  buffer = nil,
  window = nil,
  tree = {},
  filter = nil,
  saved_filters = {}
}

-- Setup function for user configuration
function M.setup(opts)
  opts = opts or {}
  M.options = vim.tbl_deep_extend('force', M.options, opts)
  
  -- Initialize cache with configured TTLs
  local cache = require('aws-nvim.cache')
  cache.default_ttl = M.options.cache_ttl
  cache.init()
  
  -- Load last used profile and region if available
  local preferences = cache.load_preferences()
  if preferences.region then
    M.options.region = preferences.region
  end
  if preferences.profile then
    M.options.profile = preferences.profile
  end
end

-- Save current profile and region preferences
function M.save_preferences()
  local cache = require('aws-nvim.cache')
  cache.save_preferences({
    region = M.options.region,
    profile = M.options.profile
  })
end

-- Get status icon based on resource status
function M.get_status_icon(status, health)
  if not status then
    return M.options.icons.status.unknown
  end
  
  -- Status mappings for different resource types
  local status_lower = string.lower(status)
  
  if string.match(status_lower, "complete") or 
     status == "ACTIVE" or 
     (status == "RUNNING" and (not health or health == "HEALTHY")) then
    return M.options.icons.status.ok
  elseif string.match(status_lower, "progress") or 
         string.match(status_lower, "update") then
    return M.options.icons.loading
  elseif string.match(status_lower, "fail") or 
         status == "STOPPED" or 
         health == "UNHEALTHY" then
    return M.options.icons.status.error
  else
    return M.options.icons.status.unknown
  end
end

-- Get icon based on node type and state
function M.get_node_icon(node)
  if node.loading then
    return M.options.icons.loading
  end
  
  if node.has_children then
    return node.expanded and M.options.icons.expanded or M.options.icons.collapsed
  else
    return M.options.icons.leaf
  end
end

-- Create cache key for resource
function M.create_cache_key(resource_type, resource_id, parent_id)
  if resource_type == 'stacks' then
    return 'stacks:' .. M.options.region
  elseif resource_type == 'services' then
    return 'stack:' .. parent_id .. ':services'
  elseif resource_type == 'tasks' then
    return 'service:' .. parent_id .. ':tasks'
  elseif resource_type == 'containers' then
    return 'task:' .. parent_id .. ':containers'
  else
    return resource_type .. ':' .. resource_id
  end
end

-- Validate AWS credentials are available
function M.validate_aws_credentials(callback)
  local aws = require('aws-nvim.aws')
  aws.run_aws_command('sts get-caller-identity', M.options.region, M.options.profile, function(err, result)
    if err then
      callback(false, "AWS credentials error: " .. err)
    else
      callback(true, result)
    end
  end)
end

return M 