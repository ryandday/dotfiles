local M = {}

-- Default configuration
local default_config = {
  data_path = vim.fn.stdpath("data") .. "/bookmark-sets.json",
  current_set = "default",
  auto_save = true,
  max_recent_sets = 10,
  enable_numbered_jumps = true, -- Enable 1-9 quick jumps
}

-- Plugin state
local config = {}
local data = {
  sets = {},
  current_set = "default",
  recent_sets = {},
}

-- Helper function to ensure data structure
local function ensure_data_structure()
  if not data.sets then
    data.sets = {}
  end
  if not data.sets[data.current_set] then
    data.sets[data.current_set] = {
      name = data.current_set,
      bookmarks = {},
      created = os.time(),
      modified = os.time(),
    }
  end
  if not data.recent_sets then
    data.recent_sets = {}
  end
end

-- Save data to file
local function save_data()
  if not config.auto_save then
    return
  end
  
  ensure_data_structure()
  data.modified = os.time()
  
  local file = io.open(config.data_path, "w")
  if file then
    file:write(vim.json.encode(data))
    file:close()
  else
    vim.notify("Failed to save bookmark sets to " .. config.data_path, vim.log.levels.ERROR)
  end
end

-- Load data from file
local function load_data()
  local file = io.open(config.data_path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    
    local ok, loaded_data = pcall(vim.json.decode, content)
    if ok and type(loaded_data) == "table" then
      data = loaded_data
      if data.current_set then
        -- Validate current set exists
        if not data.sets[data.current_set] then
          data.current_set = "default"
        end
      end
    end
  end
  
  ensure_data_structure()
end

-- Update recent sets list
local function update_recent_sets(set_name)
  if not data.recent_sets then
    data.recent_sets = {}
  end
  
  -- Remove if already exists
  for i, name in ipairs(data.recent_sets) do
    if name == set_name then
      table.remove(data.recent_sets, i)
      break
    end
  end
  
  -- Add to front
  table.insert(data.recent_sets, 1, set_name)
  
  -- Limit size
  if #data.recent_sets > config.max_recent_sets then
    table.remove(data.recent_sets)
  end
end

-- Get current timestamp
local function get_timestamp()
  return os.time()
end

-- Format relative path
local function format_path(filepath)
  return vim.fn.fnamemodify(filepath, ":~:.")
end

-- Clean up non-existent files
local function cleanup_bookmarks(set_name)
  local set_data = data.sets[set_name]
  if not set_data then
    return
  end
  
  local cleaned = {}
  local removed_count = 0
  
  for _, bookmark in ipairs(set_data.bookmarks) do
    if vim.fn.filereadable(bookmark.file) == 1 then
      table.insert(cleaned, bookmark)
    else
      removed_count = removed_count + 1
    end
  end
  
  set_data.bookmarks = cleaned
  set_data.modified = get_timestamp()
  
  if removed_count > 0 then
    vim.notify(string.format("Removed %d non-existent files from set '%s'", removed_count, set_name), vim.log.levels.INFO)
    save_data()
  end
end

-- Add bookmark to current set
function M.add_bookmark()
  local current_file = vim.fn.expand("%:p")
  local current_line = vim.fn.line(".")
  
  if current_file == "" then
    vim.notify("No file is currently open", vim.log.levels.WARN)
    return
  end
  
  -- Prompt for nickname
  vim.ui.input({
    prompt = "Bookmark nickname (optional): ",
    default = "",
  }, function(nickname)
    nickname = nickname and vim.trim(nickname) or ""
    if nickname == "" then
      nickname = nil
    end
    
    ensure_data_structure()
    local current_set = data.sets[data.current_set]
    
    -- Check if exact bookmark already exists (same file AND same line)
    -- This allows multiple bookmarks per file at different lines
    for i, bookmark in ipairs(current_set.bookmarks) do
      if bookmark.file == current_file and bookmark.line == current_line then
        -- Update existing bookmark at this exact location
        bookmark.nickname = nickname
        bookmark.modified = get_timestamp()
        current_set.modified = get_timestamp()
        save_data()
        vim.notify("Updated bookmark in set '" .. data.current_set .. "'", vim.log.levels.INFO)
        return
      end
    end
    
    -- Add new bookmark (allows multiple lines per file)
    local bookmark = {
      file = current_file,
      line = current_line,
      nickname = nickname,
      created = get_timestamp(),
      modified = get_timestamp(),
    }
    
    table.insert(current_set.bookmarks, bookmark)
    current_set.modified = get_timestamp()
    save_data()
    
    local display_name = nickname or format_path(current_file) .. ":" .. current_line
    vim.notify("Added bookmark '" .. display_name .. "' to set '" .. data.current_set .. "'", vim.log.levels.INFO)
  end)
end

-- Format bookmark for display
local function format_bookmark(bookmark, index)
  local display_name = bookmark.nickname or vim.fn.fnamemodify(bookmark.file, ":t")
  local path = format_path(bookmark.file)
  return string.format("%d: %s [%s:%d]", index, display_name, path, bookmark.line)
end

-- Jump to bookmark by number (1-9)
function M.jump_to_bookmark(number)
  ensure_data_structure()
  local current_set = data.sets[data.current_set]
  
  if #current_set.bookmarks == 0 then
    vim.notify("No bookmarks in set '" .. data.current_set .. "'", vim.log.levels.WARN)
    return
  end
  
  if number < 1 or number > #current_set.bookmarks then
    vim.notify("Bookmark " .. number .. " doesn't exist (only " .. #current_set.bookmarks .. " bookmarks available)", vim.log.levels.WARN)
    return
  end
  
  local bookmark = current_set.bookmarks[number]
  if vim.fn.filereadable(bookmark.file) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(bookmark.file))
    vim.fn.cursor(bookmark.line, 1)
    vim.cmd("normal! zz")
    
    local display_name = bookmark.nickname or format_path(bookmark.file) .. ":" .. bookmark.line
    vim.notify("Jumped to bookmark " .. number .. ": " .. display_name, vim.log.levels.INFO)
  else
    vim.notify("Bookmark file no longer exists: " .. bookmark.file, vim.log.levels.WARN)
  end
end

-- Fuzzy find bookmarks in current set
function M.find_bookmark()
  ensure_data_structure()
  local current_set = data.sets[data.current_set]
  
  if #current_set.bookmarks == 0 then
    vim.notify("No bookmarks in set '" .. data.current_set .. "'", vim.log.levels.WARN)
    return
  end
  
  -- Clean up first
  cleanup_bookmarks(data.current_set)
  
  local items = {}
  for i, bookmark in ipairs(current_set.bookmarks) do
    table.insert(items, format_bookmark(bookmark, i))
  end
  
  vim.ui.select(items, {
    prompt = "Select bookmark (set: " .. data.current_set .. "):",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if choice and idx then
      local bookmark = current_set.bookmarks[idx]
      vim.cmd("edit " .. vim.fn.fnameescape(bookmark.file))
      vim.fn.cursor(bookmark.line, 1)
      vim.cmd("normal! zz")
    end
  end)
end

-- Delete bookmark from current set
function M.delete_bookmark()
  ensure_data_structure()
  local current_set = data.sets[data.current_set]
  
  if #current_set.bookmarks == 0 then
    vim.notify("No bookmarks in set '" .. data.current_set .. "'", vim.log.levels.WARN)
    return
  end
  
  local items = {}
  for i, bookmark in ipairs(current_set.bookmarks) do
    table.insert(items, format_bookmark(bookmark, i))
  end
  
  vim.ui.select(items, {
    prompt = "Delete bookmark from set '" .. data.current_set .. "':",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if choice and idx then
      local bookmark = current_set.bookmarks[idx]
      local display_name = bookmark.nickname or format_path(bookmark.file) .. ":" .. bookmark.line
      
      table.remove(current_set.bookmarks, idx)
      current_set.modified = get_timestamp()
      save_data()
      
      vim.notify("Deleted bookmark '" .. display_name .. "' from set '" .. data.current_set .. "'", vim.log.levels.INFO)
    end
  end)
end

-- Create new set
function M.create_set()
  vim.ui.input({
    prompt = "New set name: ",
    default = "",
  }, function(set_name)
    if not set_name or vim.trim(set_name) == "" then
      return
    end
    
    set_name = vim.trim(set_name)
    ensure_data_structure()
    
    if data.sets[set_name] then
      vim.notify("Set '" .. set_name .. "' already exists", vim.log.levels.WARN)
      return
    end
    
    data.sets[set_name] = {
      name = set_name,
      bookmarks = {},
      created = get_timestamp(),
      modified = get_timestamp(),
    }
    
    data.current_set = set_name
    update_recent_sets(set_name)
    save_data()
    
    vim.notify("Created and switched to set '" .. set_name .. "'", vim.log.levels.INFO)
  end)
end

-- Rename current set
function M.rename_set()
  ensure_data_structure()
  
  if data.current_set == "default" then
    vim.notify("Cannot rename the default set", vim.log.levels.WARN)
    return
  end
  
  vim.ui.input({
    prompt = "Rename set '" .. data.current_set .. "' to: ",
    default = data.current_set,
  }, function(new_name)
    if not new_name or vim.trim(new_name) == "" then
      return
    end
    
    new_name = vim.trim(new_name)
    
    if new_name == data.current_set then
      return -- No change
    end
    
    if data.sets[new_name] then
      vim.notify("Set '" .. new_name .. "' already exists", vim.log.levels.WARN)
      return
    end
    
    -- Copy the set data
    local old_name = data.current_set
    data.sets[new_name] = data.sets[old_name]
    data.sets[new_name].name = new_name
    data.sets[new_name].modified = get_timestamp()
    
    -- Remove old set
    data.sets[old_name] = nil
    
    -- Update current set and recent sets
    data.current_set = new_name
    update_recent_sets(new_name)
    
    -- Remove old name from recent sets
    for i, name in ipairs(data.recent_sets) do
      if name == old_name then
        table.remove(data.recent_sets, i)
        break
      end
    end
    
    save_data()
    vim.notify("Renamed set '" .. old_name .. "' to '" .. new_name .. "'", vim.log.levels.INFO)
  end)
end

-- Switch to different set
function M.switch_set()
  ensure_data_structure()
  
  local set_names = {}
  for name, _ in pairs(data.sets) do
    table.insert(set_names, name)
  end
  
  if #set_names == 0 then
    vim.notify("No bookmark sets available", vim.log.levels.WARN)
    return
  end
  
  table.sort(set_names)
  
  -- Format items with preview
  local items = {}
  for _, name in ipairs(set_names) do
    local set_data = data.sets[name]
    local bookmark_count = #set_data.bookmarks
    local current_marker = (name == data.current_set) and " (current)" or ""
    local item = string.format("%s [%d bookmarks]%s", name, bookmark_count, current_marker)
    table.insert(items, item)
  end
  
  vim.ui.select(items, {
    prompt = "Switch to set:",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if choice and idx then
      local selected_set = set_names[idx]
      data.current_set = selected_set
      update_recent_sets(selected_set)
      save_data()
      vim.notify("Switched to set '" .. selected_set .. "'", vim.log.levels.INFO)
    end
  end)
end

-- Delete set
function M.delete_set()
  ensure_data_structure()
  
  local set_names = {}
  for name, _ in pairs(data.sets) do
    if name ~= "default" then  -- Protect default set
      table.insert(set_names, name)
    end
  end
  
  if #set_names == 0 then
    vim.notify("No deletable sets available (default set is protected)", vim.log.levels.WARN)
    return
  end
  
  table.sort(set_names)
  
  vim.ui.select(set_names, {
    prompt = "Delete set:",
    format_item = function(item)
      local bookmark_count = #data.sets[item].bookmarks
      return string.format("%s [%d bookmarks]", item, bookmark_count)
    end,
  }, function(choice, idx)
    if choice and idx then
      local set_to_delete = set_names[idx]
      
      -- Confirm deletion
      vim.ui.input({
        prompt = "Type 'DELETE' to confirm deletion of set '" .. set_to_delete .. "': ",
        default = "",
      }, function(confirmation)
        if confirmation == "DELETE" then
          data.sets[set_to_delete] = nil
          
          -- Switch to default if deleting current set
          if data.current_set == set_to_delete then
            data.current_set = "default"
            ensure_data_structure()
          end
          
          -- Remove from recent sets
          for i, name in ipairs(data.recent_sets) do
            if name == set_to_delete then
              table.remove(data.recent_sets, i)
              break
            end
          end
          
          save_data()
          vim.notify("Deleted set '" .. set_to_delete .. "'", vim.log.levels.INFO)
        end
      end)
    end
  end)
end

-- Show current set info
function M.show_set_info()
  ensure_data_structure()
  local current_set = data.sets[data.current_set]
  
  local info = {
    "Bookmark Set: " .. data.current_set,
    "Bookmarks: " .. #current_set.bookmarks,
    "Created: " .. os.date("%Y-%m-%d %H:%M:%S", current_set.created),
    "Modified: " .. os.date("%Y-%m-%d %H:%M:%S", current_set.modified),
    "",
  }
  
  if #current_set.bookmarks > 0 then
    table.insert(info, "Bookmarks:")
    for i, bookmark in ipairs(current_set.bookmarks) do
      local display = format_bookmark(bookmark, i)
      table.insert(info, "  " .. display)
    end
  else
    table.insert(info, "No bookmarks in this set")
  end
  
  vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
end

-- Cleanup all sets
function M.cleanup_all_sets()
  ensure_data_structure()
  
  local total_removed = 0
  for set_name, _ in pairs(data.sets) do
    local before_count = #data.sets[set_name].bookmarks
    cleanup_bookmarks(set_name)
    local after_count = #data.sets[set_name].bookmarks
    total_removed = total_removed + (before_count - after_count)
  end
  
  if total_removed > 0 then
    vim.notify(string.format("Cleaned up %d non-existent bookmarks across all sets", total_removed), vim.log.levels.INFO)
  else
    vim.notify("No cleanup needed - all bookmarks are valid", vim.log.levels.INFO)
  end
end

-- Setup function
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", default_config, user_config or {})
  
  -- Ensure data directory exists
  local data_dir = vim.fn.fnamemodify(config.data_path, ":h")
  if vim.fn.isdirectory(data_dir) == 0 then
    vim.fn.mkdir(data_dir, "p")
  end
  
  load_data()
  
  -- Set up keymaps
  local opts = { noremap = true, silent = true }
  
  vim.keymap.set("n", "<leader>ba", M.add_bookmark, opts) -- Add bookmark
  vim.keymap.set("n", "<leader>bf", M.find_bookmark, opts) -- Find bookmark
  vim.keymap.set("n", "<leader>bd", M.delete_bookmark, opts) -- Delete bookmark
  vim.keymap.set("n", "<leader>bc", M.create_set, opts) -- Create set
  vim.keymap.set("n", "<leader>br", M.rename_set, opts) -- Rename set
  vim.keymap.set("n", "<leader>bs", M.switch_set, opts) -- Switch set
  vim.keymap.set("n", "<leader>bx", M.delete_set, opts) -- Delete set (eXterminate)
  vim.keymap.set("n", "<leader>bi", M.show_set_info, opts) -- Info about current set
  vim.keymap.set("n", "<leader>bC", M.cleanup_all_sets, opts) -- Cleanup all sets
  
  -- Set up numbered jumps (1-9) if enabled
  if config.enable_numbered_jumps then
    for i = 1, 9 do
      vim.keymap.set("n", "<leader>b" .. i, function() M.jump_to_bookmark(i) end, opts)
    end
  end
  
  -- Create commands
  vim.api.nvim_create_user_command("BookmarkAdd", M.add_bookmark, {})
  vim.api.nvim_create_user_command("BookmarkFind", M.find_bookmark, {})
  vim.api.nvim_create_user_command("BookmarkDelete", M.delete_bookmark, {})
  vim.api.nvim_create_user_command("BookmarkSetCreate", M.create_set, {})
  vim.api.nvim_create_user_command("BookmarkSetRename", M.rename_set, {})
  vim.api.nvim_create_user_command("BookmarkSetSwitch", M.switch_set, {})
  vim.api.nvim_create_user_command("BookmarkSetDelete", M.delete_set, {})
  vim.api.nvim_create_user_command("BookmarkSetInfo", M.show_set_info, {})
  vim.api.nvim_create_user_command("BookmarkCleanup", M.cleanup_all_sets, {})
  
  -- Create numbered jump commands if enabled
  if config.enable_numbered_jumps then
    for i = 1, 9 do
      vim.api.nvim_create_user_command("BookmarkJump" .. i, function() M.jump_to_bookmark(i) end, {})
    end
  end
end

return M 