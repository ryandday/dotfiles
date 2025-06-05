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
    -- Also clear the reverse preference
    local target_file = preferences[pref_key]
    local reverse_key = get_preference_key(target_file)
    preferences[pref_key] = nil
    preferences[reverse_key] = nil
    save_preferences()
    
    local basename = get_basename(current_file)
    local directory = get_directory(current_file)
    local remote_url = get_git_remote_url(directory)
    
    if remote_url then
      vim.notify("Cleared preferences for " .. basename .. " (repo: " .. remote_url .. ")", vim.log.levels.INFO)
    else
      vim.notify("Cleared preferences for " .. basename, vim.log.levels.INFO)
    end
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

-- Find project root (prioritize git repository root)
local function find_project_root(start_dir)
  local current = start_dir
  local git_root = nil
  local other_root = nil
  
  local other_indicators = {
    "CMakeLists.txt", "Makefile", "configure.ac", "configure.in",
    "Cargo.toml", "package.json", "pom.xml", "build.gradle", ".project"
  }
  
  while current ~= "/" do
    -- Check for .git directory first (highest priority)
    local git_path = current .. "/.git"
    if vim.fn.isdirectory(git_path) == 1 then
      git_root = current
      -- Don't break here, keep going up to find the topmost git repo
    end
    
    -- Check for other project indicators only if we haven't found git yet
    if not other_root then
      for _, indicator in ipairs(other_indicators) do
        local path = current .. "/" .. indicator
        if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
          other_root = current
          break
        end
      end
    end
    
    current = vim.fn.fnamemodify(current, ":h")
  end
  
  -- Prefer git root over other indicators
  return git_root or other_root or start_dir
end

-- Find corresponding files with git-aware search
local function find_corresponding_files(current_file)
  local current_ext = get_extension(current_file)
  local basename = get_basename(current_file)
  local directory = get_directory(current_file)
  
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
  
  local project_root = find_project_root(directory)
  
  local matches = {}
  
  -- Use git to find all tracked files (respects .gitignore and is much faster)
  local function find_files_with_git()
    local git_files = {}
    
    -- Try to use git ls-files to get all tracked files
    local handle = io.popen("cd " .. vim.fn.shellescape(project_root) .. " && git ls-files 2>/dev/null")
    if handle then
      for line in handle:lines() do
        if line and line ~= "" then
          local full_path = project_root .. "/" .. line
          table.insert(git_files, full_path)
        end
      end
      handle:close()
    end
    
    return git_files
  end
  
  -- Fallback to recursive directory scan if git is not available
  local function find_files_recursively()
    local all_files = {}
    
    local function search_recursively(search_dir, max_depth)
      if max_depth <= 0 then return end
      
      local handle = vim.loop.fs_scandir(search_dir)
      if not handle then return end
      
      local name, type = vim.loop.fs_scandir_next(handle)
      while name do
        local full_path = search_dir .. "/" .. name
        
        if type == "file" then
          table.insert(all_files, full_path)
        elseif type == "directory" and not name:match("^%.") and name ~= "node_modules" and name ~= ".git" then
          -- Skip common directories that we don't want to search
          search_recursively(full_path, max_depth - 1)
        end
        
        name, type = vim.loop.fs_scandir_next(handle)
      end
    end
    
    search_recursively(project_root, 10)
    return all_files
  end
  
  -- Get all files in the repository
  local all_files = find_files_with_git()
  if #all_files == 0 then
    all_files = find_files_recursively()
  end
  
  -- Filter files to find matches
  for _, file_path in ipairs(all_files) do
    local file_basename = get_basename(file_path)
    local file_ext = get_extension(file_path)
    
    if file_basename == basename then
      for _, target_ext in ipairs(target_extensions) do
        if file_ext == target_ext then
          table.insert(matches, file_path)
          break
        end
      end
    end
  end
  
  return matches
end

-- Get git remote URL for a directory
local function get_git_remote_url(directory)
  local project_root = find_project_root(directory)
  if not project_root then
    return nil
  end
  
  -- Try to get the origin remote URL
  local handle = io.popen("cd " .. vim.fn.shellescape(project_root) .. " && git remote get-url origin 2>/dev/null")
  if not handle then
    return nil
  end
  
  local remote_url = handle:read("*line")
  handle:close()
  
  if remote_url and remote_url ~= "" then
    -- Normalize the URL (remove .git suffix, convert SSH to HTTPS format for consistency)
    remote_url = remote_url:gsub("%.git$", "")
    remote_url = remote_url:gsub("^git@([^:]+):", "https://%1/")
    return remote_url
  end
  
  return nil
end

-- Get preference key for current file (now based on git remote instead of directory)
local function get_preference_key(current_file)
  local basename = get_basename(current_file)
  local directory = get_directory(current_file)
  local remote_url = get_git_remote_url(directory)
  
  if remote_url then
    -- Use git remote URL as the key prefix
    return remote_url .. "/" .. basename
  else
    -- Fallback to directory-based key if no git remote found
    return directory .. "/" .. basename
  end
end

-- Save bidirectional preference
local function save_bidirectional_preference(file_a, file_b)
  local key_a = get_preference_key(file_a)
  local key_b = get_preference_key(file_b)
  
  -- Save preferences in both directions
  preferences[key_a] = file_b
  preferences[key_b] = file_a
  save_preferences()
  
  local basename = get_basename(file_a)
  local directory = get_directory(file_a)
  local remote_url = get_git_remote_url(directory)
  
  if remote_url then
    vim.notify("Preference saved for " .. basename .. " (repo: " .. remote_url .. ")", vim.log.levels.INFO)
  else
    vim.notify("Preference saved for " .. basename, vim.log.levels.INFO)
  end
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
      -- Remember the choice bidirectionally
      save_bidirectional_preference(current_file, selected_file)
      vim.cmd("edit " .. vim.fn.fnameescape(selected_file))
    end
  end)
end

-- Create command to clear preference for current file
vim.api.nvim_create_user_command('HeaderSourceClearPreference', clear_preference_for_current_file, {
  desc = 'Clear header/source preference for current file'
})

return M
