local M = {}

-- File extension mappings
local header_extensions = { "h", "hpp", "hh" }
local source_extensions = { "cpp", "cc" }

-- Store user preferences for file choices
local preferences = {}

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

-- Find corresponding files
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
  
  local matches = {}
  
  -- Search in current directory
  for _, ext in ipairs(target_extensions) do
    local candidate = directory .. "/" .. basename .. "." .. ext
    if vim.fn.filereadable(candidate) == 1 then
      table.insert(matches, candidate)
    end
  end
  
  -- Also search in common subdirectories if no matches found
  if #matches == 0 then
    local search_dirs = {
      directory .. "/src",
      directory .. "/source", 
      directory .. "/include",
      directory .. "/inc",
      directory .. "/../src",
      directory .. "/../source",
      directory .. "/../include",
      directory .. "/../inc",
    }
    
    for _, search_dir in ipairs(search_dirs) do
      if vim.fn.isdirectory(search_dir) == 1 then
        for _, ext in ipairs(target_extensions) do
          local candidate = search_dir .. "/" .. basename .. "." .. ext
          if vim.fn.filereadable(candidate) == 1 then
            table.insert(matches, candidate)
          end
        end
      end
    end
  end
  
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
      vim.cmd("edit " .. vim.fn.fnameescape(selected_file))
      vim.notify("Preference saved for " .. get_basename(current_file), vim.log.levels.INFO)
    end
  end)
end

return M 