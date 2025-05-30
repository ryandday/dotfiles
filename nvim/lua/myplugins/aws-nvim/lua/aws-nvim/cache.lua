-- cache.lua - Caching module for AWS resources
local M = {}

-- In-memory cache
M.cache = {}

-- Default TTL values (in seconds)
M.default_ttl = {
  stack = 600,     -- 10 minutes
  service = 300,   -- 5 minutes
  task = 120,      -- 2 minutes
  container = 60   -- 1 minute
}

-- File storage path
M.cache_dir = vim.fn.stdpath('cache') .. '/aws-nvim'

-- Initialize cache
function M.init()
  -- Create cache directory if it doesn't exist
  if vim.fn.isdirectory(M.cache_dir) == 0 then
    vim.fn.mkdir(M.cache_dir, 'p')
  end
  
  -- Try to load persistent cache
  M.load_persistent_cache()
end

-- Get an item from cache
-- @param key The cache key
-- @param resource_type The resource type (stack, service, task, container)
-- @return The cached data, or nil if not found or expired
function M.get(key, resource_type)
  local cache_entry = M.cache[key]
  
  -- Check if cache exists and is not expired
  if cache_entry then
    local ttl = M.default_ttl[resource_type] or 300
    if (os.time() - cache_entry.timestamp) < ttl then
      return cache_entry.data
    end
  end
  
  return nil
end

-- Set an item in cache
-- @param key The cache key
-- @param data The data to cache
-- @param resource_type The resource type (stack, service, task, container)
function M.set(key, data, resource_type)
  M.cache[key] = {
    data = data,
    timestamp = os.time(),
    type = resource_type
  }
  
  -- Save to persistent cache (async)
  vim.defer_fn(function()
    M.save_persistent_cache()
  end, 1000)  -- Save after 1 second of inactivity
end

-- Clear all cache or specific resource type
-- @param resource_type Optional resource type to clear
function M.clear(resource_type)
  if resource_type then
    -- Clear only specific resource type
    for key, entry in pairs(M.cache) do
      if entry.type == resource_type then
        M.cache[key] = nil
      end
    end
  else
    -- Clear all cache
    M.cache = {}
  end
  
  -- Save changes to persistent cache
  M.save_persistent_cache()
end

-- Invalidate a specific key and its children
-- @param key The cache key to invalidate
function M.invalidate(key)
  -- Remove exact key match
  M.cache[key] = nil
  
  -- Remove child keys (that start with this key)
  for cache_key, _ in pairs(M.cache) do
    if string.find(cache_key, "^" .. key .. ":") then
      M.cache[cache_key] = nil
    end
  end
  
  -- Save changes to persistent cache
  M.save_persistent_cache()
end

-- Save cache to persistent storage
function M.save_persistent_cache()
  -- Convert cache to a format suitable for JSON
  local cache_data = {}
  
  for key, entry in pairs(M.cache) do
    cache_data[key] = {
      data = entry.data,
      timestamp = entry.timestamp,
      type = entry.type
    }
  end
  
  -- Serialize cache to JSON
  local json_str = vim.json.encode(cache_data)
  
  -- Write to file
  local cache_file = M.cache_dir .. '/cache.json'
  local file = io.open(cache_file, "w")
  if file then
    file:write(json_str)
    file:close()
  end
end

-- Load cache from persistent storage
function M.load_persistent_cache()
  local cache_file = M.cache_dir .. '/cache.json'
  
  -- Check if cache file exists
  if vim.fn.filereadable(cache_file) == 0 then
    return
  end
  
  -- Read file
  local file = io.open(cache_file, "r")
  if not file then
    return
  end
  
  local content = file:read("*a")
  file:close()
  
  -- Parse JSON
  local success, cache_data = pcall(vim.json.decode, content)
  if not success or type(cache_data) ~= "table" then
    return
  end
  
  -- Restore cache
  M.cache = cache_data
  
  -- Clean expired entries
  M.clean_expired()
end

-- Clean expired entries from cache
function M.clean_expired()
  local now = os.time()
  local to_remove = {}
  
  -- Find expired entries
  for key, entry in pairs(M.cache) do
    local ttl = M.default_ttl[entry.type] or 300
    if (now - entry.timestamp) >= ttl then
      table.insert(to_remove, key)
    end
  end
  
  -- Remove expired entries
  for _, key in ipairs(to_remove) do
    M.cache[key] = nil
  end
  
  -- If we removed any entries, save the cache
  if #to_remove > 0 then
    M.save_persistent_cache()
  end
end

-- Save filters to a file
function M.save_filters(filters)
  -- Create cache directory if it doesn't exist
  if vim.fn.isdirectory(M.cache_dir) == 0 then
    vim.fn.mkdir(M.cache_dir, 'p')
  end
  
  local filter_file = M.cache_dir .. "/filters.json"
  
  -- Convert filters to JSON
  local json_str = vim.json.encode(filters)
  
  -- Write to file
  local file = io.open(filter_file, "w")
  if file then
    file:write(json_str)
    file:close()
    return true
  end
  
  return false
end

-- Load filters from file
function M.load_filters()
  -- Create cache directory if it doesn't exist
  if vim.fn.isdirectory(M.cache_dir) == 0 then
    vim.fn.mkdir(M.cache_dir, 'p')
  end
  
  local filter_file = M.cache_dir .. "/filters.json"
  
  -- Check if file exists
  local file = io.open(filter_file, "r")
  if not file then
    return {}
  end
  
  -- Read file content
  local content = file:read("*all")
  file:close()
  
  -- Parse JSON
  local success, filters = pcall(vim.json.decode, content)
  if success and type(filters) == "table" then
    return filters
  end
  
  return {}
end

-- Save preferences to a file
function M.save_preferences(preferences)
  -- Create cache directory if it doesn't exist
  if vim.fn.isdirectory(M.cache_dir) == 0 then
    vim.fn.mkdir(M.cache_dir, 'p')
  end
  
  local prefs_file = M.cache_dir .. "/preferences.json"
  
  -- Convert preferences to JSON
  local json_str = vim.json.encode(preferences)
  
  -- Write to file
  local file = io.open(prefs_file, "w")
  if file then
    file:write(json_str)
    file:close()
    return true
  end
  
  return false
end

-- Load preferences from file
function M.load_preferences()
  -- Create cache directory if it doesn't exist
  if vim.fn.isdirectory(M.cache_dir) == 0 then
    vim.fn.mkdir(M.cache_dir, 'p')
  end
  
  local prefs_file = M.cache_dir .. "/preferences.json"
  
  -- Check if file exists
  local file = io.open(prefs_file, "r")
  if not file then
    return {}
  end
  
  -- Read file content
  local content = file:read("*all")
  file:close()
  
  -- Parse JSON
  local success, preferences = pcall(vim.json.decode, content)
  if success and type(preferences) == "table" then
    return preferences
  end
  
  return {}
end

return M 