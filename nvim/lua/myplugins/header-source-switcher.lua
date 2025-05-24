local M = {}

-- File extension mappings
local header_extensions = { "h", "hpp", "hh" }
local source_extensions = { "cpp", "cc" }

-- Store user preferences for file choices
local preferences = {}
local preferences_file = vim.fn.stdpath("data") .. "/header-source-preferences.json"

-- Load preferences from file
local function load_preferences()
  local file = io.open(preferences_file, "r")
  if file then
    local content = file:read("*all")
    file:close()
    
    local ok, data = pcall(vim.json.decode, content)
    if ok and type(data) == "table" then
      preferences = data
      print("DEBUG: Loaded preferences:", vim.inspect(preferences))
    else
      preferences = {}
    end
  else
    preferences = {}
  end
end

-- Save preferences to file
local function save_preferences()
  local file = io.open(preferences_file, "w")
  if file then
    local content = vim.json.encode(preferences)
    file:write(content)
    file:close()
    print("DEBUG: Saved preferences to:", preferences_file)
  else
    vim.notify("Failed to save header-source preferences", vim.log.levels.ERROR)
  end
end

-- Clear preference for current file
local function clear_preference_for_current_file()
  local current_file = vim.fn.expand("%:p")
  if current_file == "" then
    vim.notify("No file is currently open", vim.log.levels.WARN)
    return
  end
  
  local pref_key = get_preference_key(current_file)
  if preferences[pref_key] then
    preferences[pref_key] = nil
    save_preferences()
    local basename = get_basename(current_file)
    vim.notify("Cleared preference for " .. basename, vim.log.levels.INFO)
  else
    local basename = get_basename(current_file)
    vim.notify("No preference found for " .. basename, vim.log.levels.INFO)
  end
end

-- Initialize preferences on load
load_preferences()

-- Helper function to get file extension
local function get_extension(filepath)
  return filepath:match("%.([^%.]+)$")
end

-- Helper function to get base name without extension
local function get_basename(filepath)
  local name = vim.fn.fnamemodify(filepath, ":t:r")
  return name
end

-- Helper function to get directory
local function get_directory(filepath)
  return vim.fn.fnamemodify(filepath, ":h")
end

-- Check if extension is a header
local function is_header(ext)
  for _, header_ext in ipairs(header_extensions) do
    if ext == header_ext then
      return true
    end
  end
  return false
end

-- Check if extension is a source file
local function is_source(ext)
  for _, source_ext in ipairs(source_extensions) do
    if ext == source_ext then
      return true
    end
  end
  return false
end

-- Find project root (look for common indicators)
local function find_project_root(start_dir)
  local indicators = {
    ".git", "CMakeLists.txt", "Makefile", "configure.ac", "configure.in",
    "Cargo.toml", "package.json", "pom.xml", "build.gradle", ".project"
  }
  
  local current = start_dir
  while current ~= "/" do
    for _, indicator in ipairs(indicators) do
      local path = current .. "/" .. indicator
      if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
        return current
      end
    end
    current = vim.fn.fnamemodify(current, ":h")
  end
  return start_dir -- fallback to original directory
end

-- Find corresponding files with global search
local function find_corresponding_files(current_file)
  local current_ext = get_extension(current_file)
  local basename = get_basename(current_file)
  local directory = get_directory(current_file)
  
  -- Debug logging
  print("DEBUG: Looking for corresponding files")
  print("DEBUG: Current file:", current_file)
  print("DEBUG: Extension:", current_ext)
  print("DEBUG: Basename:", basename)
  print("DEBUG: Directory:", directory)
  
  if not current_ext then
    return {}
  end
  
  local target_extensions = {}
  
  if is_header(current_ext) then
    target_extensions = source_extensions
  elseif is_source(current_ext) then
    target_extensions = header_extensions
  else
    return {}
  end
  
  print("DEBUG: Target extensions:", vim.inspect(target_extensions))
  
  local project_root = find_project_root(directory)
  print("DEBUG: Project root:", project_root)
  
  local matches = {}
  
  -- Global recursive search for matching files
  local function search_recursively(search_dir, max_depth)
    if max_depth <= 0 then return end
    
    local handle = vim.loop.fs_scandir(search_dir)
    if not handle then return end
    
    local name, type = vim.loop.fs_scandir_next(handle)
    while name do
      local full_path = search_dir .. "/" .. name
      
      if type == "file" then
        -- Check if this file matches our target
        local file_basename = get_basename(full_path)
        local file_ext = get_extension(full_path)
        
        if file_basename == basename then
          for _, target_ext in ipairs(target_extensions) do
            if file_ext == target_ext then
              print("DEBUG: Found match:", full_path)
              table.insert(matches, full_path)
              break
            end
          end
        end
      elseif type == "directory" and not name:match("^%.") and name ~= "node_modules" and name ~= ".git" then
        -- Skip common directories that we don't want to search
        search_recursively(full_path, max_depth - 1)
      end
      
      name, type = vim.loop.fs_scandir_next(handle)
    end
  end
  
  -- Start the recursive search from project root (limit depth to avoid performance issues)
  search_recursively(project_root, 10)
  
  print("DEBUG: Final matches:", vim.inspect(matches))
  return matches
end

-- Get preference key for current file
local function get_preference_key(current_file)
  local basename = get_basename(current_file)
  local directory = get_directory(current_file)
  return directory .. "/" .. basename
end

-- Main switch function
function M.switch()
  local current_file = vim.fn.expand("%:p")
  
  if current_file == "" then
    vim.notify("No file is currently open", vim.log.levels.WARN)
    return
  end
  
  local matches = find_corresponding_files(current_file)
  
  if #matches == 0 then
    vim.notify("No corresponding header/source file found", vim.log.levels.WARN)
    return
  end
  
  if #matches == 1 then
    -- Only one match, open it directly
    vim.cmd("edit " .. vim.fn.fnameescape(matches[1]))
    return
  end
  
  -- Multiple matches, check preference first
  local pref_key = get_preference_key(current_file)
  local preferred_file = preferences[pref_key]
  
  if preferred_file and vim.fn.filereadable(preferred_file) == 1 then
    -- Check if preferred file is still in the matches
    for _, match in ipairs(matches) do
      if match == preferred_file then
        vim.cmd("edit " .. vim.fn.fnameescape(preferred_file))
        return
      end
    end
  end
  
  -- Show picker for multiple matches
  local items = {}
  for i, match in ipairs(matches) do
    local relative_path = vim.fn.fnamemodify(match, ":~:.")
    table.insert(items, string.format("%d: %s", i, relative_path))
  end
  
  vim.ui.select(items, {
    prompt = "Select file to switch to:",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if choice and idx then
      local selected_file = matches[idx]
      -- Remember the choice
      preferences[pref_key] = selected_file
      save_preferences()
      vim.cmd("edit " .. vim.fn.fnameescape(selected_file))
      vim.notify("Preference saved for " .. get_basename(current_file), vim.log.levels.INFO)
    end
  end)
end

-- Create command to clear preference for current file
vim.api.nvim_create_user_command('HeaderSourceClearPreference', clear_preference_for_current_file, {
  desc = 'Clear header/source preference for current file'
})

return M 