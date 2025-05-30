local M = {}

-- Default configuration
local default_config = {
  data_dir = vim.fn.stdpath("data") .. "/bookmark-sets",
  auto_save = true,
  max_recent_sets = 10,
  enable_numbered_jumps = true, -- Enable quick jumps
  quick_jump_keys = { "a", "s", "d", "f", "g" }, -- Keys for quick bookmark jumps
}

-- Plugin state
local config = {}

-- Convert repository path to safe filename
local function repo_path_to_filename(repo_path)
  -- Replace path separators and other unsafe characters with underscores
  local safe_name = repo_path:gsub("[/\\:*?\"<>|]", "_")
  -- Remove multiple consecutive underscores
  safe_name = safe_name:gsub("__+", "_")
  -- Remove leading/trailing underscores
  safe_name = safe_name:gsub("^_+", ""):gsub("_+$", "")
  -- Add .json extension
  return safe_name .. ".json"
end

-- Get the root directory of the current repository
local function get_repo_root()
  local current_file = vim.fn.expand("%:p")
  local current_dir = vim.fn.expand("%:p:h")
  
  -- If no file is open, use current working directory
  if current_file == "" or current_dir == "" then
    current_dir = vim.fn.getcwd()
  end
  
  -- Try to find git root
  local git_root = vim.fn.systemlist("cd " .. vim.fn.shellescape(current_dir) .. " && git rev-parse --show-toplevel 2>/dev/null")[1]
  if git_root and git_root ~= "" then
    return git_root
  end
  
  -- Fallback to current working directory if not in a git repo
  return vim.fn.getcwd()
end

-- Get data file path for a repository
local function get_repo_data_file(repo_root)
  return config.data_dir .. "/" .. repo_path_to_filename(repo_root)
end

-- Create default repository data structure
local function create_default_repo_data()
  return {
    sets = {
      default = {
        name = "default",
        bookmarks = {},
        created = os.time(),
        modified = os.time(),
      }
    },
    current_set = "default",
    recent_sets = {},
    set_order = { "default" }, -- Explicit ordering for sets
  }
end

-- Save repository data to its file
local function save_repo_data(repo_data, repo_root)
  if not config.auto_save then
    return
  end
  
  -- Ensure data directory exists
  if vim.fn.isdirectory(config.data_dir) == 0 then
    vim.fn.mkdir(config.data_dir, "p")
  end
  
  local data_file = get_repo_data_file(repo_root)
  local file = io.open(data_file, "w")
  if file then
    file:write(vim.json.encode(repo_data))
    file:close()
  else
    vim.notify("Failed to save bookmark sets to " .. data_file, vim.log.levels.ERROR)
  end
end

-- Load repository data from its file
local function load_repo_data(repo_root)
  local data_file = get_repo_data_file(repo_root)
  local file = io.open(data_file, "r")
  
  if file then
    local content = file:read("*a")
    file:close()
    
    local ok, loaded_data = pcall(vim.json.decode, content)
    if ok and type(loaded_data) == "table" then
      -- Ensure the loaded data has the expected structure
      if not loaded_data.sets then
        loaded_data.sets = {}
      end
      if not loaded_data.sets.default then
        loaded_data.sets.default = {
          name = "default",
          bookmarks = {},
          created = os.time(),
          modified = os.time(),
        }
      end
      if not loaded_data.current_set then
        loaded_data.current_set = "default"
      end
      if not loaded_data.recent_sets then
        loaded_data.recent_sets = {}
      end
      -- Migrate or create set_order if missing
      if not loaded_data.set_order then
        loaded_data.set_order = vim.tbl_keys(loaded_data.sets)
        table.sort(loaded_data.set_order)
      end
      return loaded_data
    end
  end
  
  -- Return default data if file doesn't exist or is invalid
  return create_default_repo_data()
end

-- Get current timestamp
local function get_timestamp()
  return os.time()
end

-- Format relative path
local function format_path(filepath)
  return vim.fn.fnamemodify(filepath, ":~:.")
end

-- Update recent sets list
local function update_recent_sets(repo_data, set_name)
  if not repo_data.recent_sets then
    repo_data.recent_sets = {}
  end
  
  -- Remove if already exists
  for i, name in ipairs(repo_data.recent_sets) do
    if name == set_name then
      table.remove(repo_data.recent_sets, i)
      break
    end
  end
  
  -- Add to front
  table.insert(repo_data.recent_sets, 1, set_name)
  
  -- Limit size
  if #repo_data.recent_sets > config.max_recent_sets then
    table.remove(repo_data.recent_sets)
  end
end

-- Clean up non-existent files
local function cleanup_bookmarks(repo_data, set_name)
  local set_data = repo_data.sets[set_name]
  if not set_data then
    return 0
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
  
  return removed_count
end

-- Format bookmark for display
local function format_bookmark(bookmark, index)
  local display_name = bookmark.nickname or vim.fn.fnamemodify(bookmark.file, ":t")
  local path = format_path(bookmark.file)
  return string.format("%-20s [%s:%d]", display_name, path, bookmark.line)
end

-- Main UI function
function M.show_ui()
  local repo_root = get_repo_root()
  local repo_data = load_repo_data(repo_root)
  local repo_key = vim.fn.fnamemodify(repo_root, ":t")
  
  -- State variables
  local current_view = "sets" -- "sets" or "bookmarks"
  local current_set = nil
  local cursor_pos = 1
  local buf, win
  
  -- Create window
  local function create_window()
    buf = vim.api.nvim_create_buf(false, true)
    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = math.min(100, vim.o.columns - 4),
      height = math.min(25, vim.o.lines - 4),
      col = math.floor((vim.o.columns - math.min(100, vim.o.columns - 4)) / 2),
      row = math.floor((vim.o.lines - math.min(25, vim.o.lines - 4)) / 2),
      style = "minimal",
      border = "rounded",
      title = " Bookmark Manager - " .. repo_key .. " ",
      title_pos = "center",
    })
    
    vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf, "filetype", "bookmark-manager")
  end
  
  -- Update buffer content
  local function update_buffer()
    local lines = {}
    local items = {}
    
    if current_view == "sets" then
      -- Show sets view
      table.insert(lines, "")
      table.insert(lines, "  📁 Bookmark Sets")
      local current_indicator = repo_data.current_set and " (current: " .. repo_data.current_set .. ")" or ""
      table.insert(lines, "  Repository: " .. repo_key .. current_indicator)
      table.insert(lines, "")
      table.insert(lines, string.rep("─", 96))
      
      -- Use explicit order instead of sorting keys
      local set_names = {}
      for _, name in ipairs(repo_data.set_order or {}) do
        if repo_data.sets[name] then
          table.insert(set_names, name)
        end
      end
      
      -- Add any sets that might not be in the order list
      for name, _ in pairs(repo_data.sets) do
        local found = false
        for _, ordered_name in ipairs(set_names) do
          if ordered_name == name then
            found = true
            break
          end
        end
        if not found then
          table.insert(set_names, name)
          table.insert(repo_data.set_order, name)
        end
      end
      
      if #set_names == 0 then
        table.insert(lines, "")
        table.insert(lines, "  No bookmark sets found. Press 'a' to add one.")
        table.insert(lines, "")
      else
        for i, set_name in ipairs(set_names) do
          local set_data = repo_data.sets[set_name]
          local bookmark_count = set_data and #(set_data.bookmarks or {}) or 0
          local current_mark = set_name == repo_data.current_set and " ★" or ""
          local prefix = i == cursor_pos and "▶ " or "  "
          table.insert(lines, string.format("%s%2d. %-25s (%d bookmarks)%s", prefix, i, set_name, bookmark_count, current_mark))
          table.insert(items, { type = "set", name = set_name, index = i })
        end
      end
      
      table.insert(lines, "")
      table.insert(lines, string.rep("─", 96))
      table.insert(lines, "  ENTER=open x=delete  r=rename  s=switch  c=cleanup  q=quit")
      table.insert(lines, "  Ctrl+j/k=move  j/k=navigate  a=add")
      
    else
      -- Show bookmarks view for current set
      table.insert(lines, "")
      table.insert(lines, "  📄 Bookmarks in Set: " .. current_set)
      table.insert(lines, "  Repository: " .. repo_key)
      table.insert(lines, "")
      table.insert(lines, string.rep("─", 96))
      
      local set_data = repo_data.sets[current_set]
      local bookmarks = set_data and set_data.bookmarks or {}
      
      if #bookmarks == 0 then
        table.insert(lines, "")
        table.insert(lines, "  No bookmarks in this set. Use BookmarkAdd when in a file.")
        table.insert(lines, "")
      else
        for i, bookmark in ipairs(bookmarks) do
          local display = format_bookmark(bookmark, i)
          local prefix = i == cursor_pos and "▶ " or "  "
          local quick_key = ""
          if i <= #config.quick_jump_keys then
            quick_key = " (\\" .. config.quick_jump_keys[i] .. ")"
          end
          table.insert(lines, string.format("%s%2d. %s%s", prefix, i, display, quick_key))
          table.insert(items, { type = "bookmark", bookmark = bookmark, index = i })
        end
      end
      
      table.insert(lines, "")
      table.insert(lines, string.rep("─", 96))
      table.insert(lines, "  ENTER=jump  x=delete  r=rename  c=cleanup  b=back  q=quit")
      table.insert(lines, "  Ctrl+j/k=move  j/k=navigate  p=replace")
    end
    
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    
    return items
  end
  
  -- Navigation functions
  local function move_cursor(direction, items)
    if #items == 0 then return end
    
    if direction == "down" then
      cursor_pos = cursor_pos < #items and cursor_pos + 1 or cursor_pos
    else -- up
      cursor_pos = cursor_pos > 1 and cursor_pos - 1 or cursor_pos
    end
  end
  
  local function move_item(direction, items)
    if #items == 0 or cursor_pos < 1 or cursor_pos > #items then return end
    
    if current_view == "sets" then
      -- Use explicit order array instead of key manipulation
      local set_names = {}
      for _, name in ipairs(repo_data.set_order or {}) do
        if repo_data.sets[name] then
          table.insert(set_names, name)
        end
      end
      
      if #set_names < 2 then return end
      
      local target_pos = direction == "down" and cursor_pos + 1 or cursor_pos - 1
      
      if target_pos < 1 or target_pos > #set_names then return end
      
      -- Swap positions in the order array
      local temp = set_names[cursor_pos]
      set_names[cursor_pos] = set_names[target_pos]
      set_names[target_pos] = temp
      
      -- Update the order array
      repo_data.set_order = set_names
      
      cursor_pos = target_pos
      save_repo_data(repo_data, repo_root)
      
    else -- bookmarks view
      local set_data = repo_data.sets[current_set]
      if not set_data or not set_data.bookmarks or #set_data.bookmarks < 2 then return end
      
      local target_pos = direction == "down" and cursor_pos + 1 or cursor_pos - 1
      
      if target_pos < 1 or target_pos > #set_data.bookmarks then return end
      
      -- Swap bookmarks
      local temp = set_data.bookmarks[cursor_pos]
      set_data.bookmarks[cursor_pos] = set_data.bookmarks[target_pos]
      set_data.bookmarks[target_pos] = temp
      
      cursor_pos = target_pos
      set_data.modified = get_timestamp()
      save_repo_data(repo_data, repo_root)
    end
  end
  
  -- Action functions
  local function add_item()
    if current_view == "sets" then
      vim.ui.input({
        prompt = "Set name: ",
      }, function(name)
        if not name or name == "" then return end
        
        if repo_data.sets[name] then
          vim.notify("Set '" .. name .. "' already exists", vim.log.levels.ERROR)
          return
        end
        
        repo_data.sets = repo_data.sets or {}
        repo_data.sets[name] = {
          name = name,
          bookmarks = {},
          created = get_timestamp(),
          modified = get_timestamp(),
        }
        
        -- Add to order list
        if not repo_data.set_order then
          repo_data.set_order = {}
        end
        table.insert(repo_data.set_order, name)
        
        if not repo_data.current_set then
          repo_data.current_set = name
        end
        
        update_recent_sets(repo_data, name)
        save_repo_data(repo_data, repo_root)
        vim.notify("Set '" .. name .. "' created", vim.log.levels.INFO)
      end)
    else
      vim.notify("Use BookmarkAdd command when in a file to add bookmarks", vim.log.levels.INFO)
    end
  end
  
  local function delete_item(items)
    if #items == 0 or cursor_pos < 1 or cursor_pos > #items then return end
    
    local item = items[cursor_pos]
    
    if current_view == "sets" then
      if item.name == "default" then
        vim.notify("Cannot delete the default set", vim.log.levels.WARN)
        return
      end
      
      vim.ui.input({
        prompt = "Delete set '" .. item.name .. "'? (y/N): ",
      }, function(confirm)
        if confirm and confirm:lower():match("^y") then
          repo_data.sets[item.name] = nil
          
          -- Remove from order array
          if repo_data.set_order then
            for i, name in ipairs(repo_data.set_order) do
              if name == item.name then
                table.remove(repo_data.set_order, i)
                break
              end
            end
          end
          
          if repo_data.current_set == item.name then
            repo_data.current_set = "default"
          end
          
          -- Remove from recent sets
          for i, name in ipairs(repo_data.recent_sets) do
            if name == item.name then
              table.remove(repo_data.recent_sets, i)
              break
            end
          end
          
          save_repo_data(repo_data, repo_root)
          cursor_pos = math.min(cursor_pos, #(repo_data.set_order or {}))
          vim.notify("Set '" .. item.name .. "' deleted", vim.log.levels.INFO)
        end
      end)
    else
      local bookmark = item.bookmark
      local display_name = bookmark.nickname or format_path(bookmark.file) .. ":" .. bookmark.line
      
      vim.ui.input({
        prompt = "Delete bookmark '" .. display_name .. "'? (y/N): ",
      }, function(confirm)
        if confirm and confirm:lower():match("^y") then
          local set_data = repo_data.sets[current_set]
          table.remove(set_data.bookmarks, cursor_pos)
          set_data.modified = get_timestamp()
          save_repo_data(repo_data, repo_root)
          cursor_pos = math.min(cursor_pos, #set_data.bookmarks)
          vim.notify("Bookmark '" .. display_name .. "' deleted", vim.log.levels.INFO)
        end
      end)
    end
  end
  
  local function rename_item(items)
    if #items == 0 or cursor_pos < 1 or cursor_pos > #items then return end
    
    local item = items[cursor_pos]
    
    if current_view == "sets" then
      if item.name == "default" then
        vim.notify("Cannot rename the default set", vim.log.levels.WARN)
        return
      end
      
      vim.ui.input({
        prompt = "New set name: ",
        default = item.name,
      }, function(new_name)
        if not new_name or new_name == "" or new_name == item.name then return end
        
        if repo_data.sets[new_name] then
          vim.notify("Set '" .. new_name .. "' already exists", vim.log.levels.ERROR)
          return
        end
        
        repo_data.sets[new_name] = repo_data.sets[item.name]
        repo_data.sets[new_name].name = new_name
        repo_data.sets[new_name].modified = get_timestamp()
        repo_data.sets[item.name] = nil
        
        -- Update order array
        if repo_data.set_order then
          for i, name in ipairs(repo_data.set_order) do
            if name == item.name then
              repo_data.set_order[i] = new_name
              break
            end
          end
        end
        
        if repo_data.current_set == item.name then
          repo_data.current_set = new_name
        end
        
        update_recent_sets(repo_data, new_name)
        
        -- Remove old name from recent sets
        for i, name in ipairs(repo_data.recent_sets) do
          if name == item.name then
            table.remove(repo_data.recent_sets, i)
            break
          end
        end
        
        save_repo_data(repo_data, repo_root)
        vim.notify("Set renamed to '" .. new_name .. "'", vim.log.levels.INFO)
      end)
    else
      local bookmark = item.bookmark
      vim.ui.input({
        prompt = "New bookmark nickname: ",
        default = bookmark.nickname or "",
      }, function(new_name)
        if not new_name then return end
        
        new_name = vim.trim(new_name)
        if new_name == "" then
          new_name = nil
        end
        
        local set_data = repo_data.sets[current_set]
        set_data.bookmarks[cursor_pos].nickname = new_name
        set_data.bookmarks[cursor_pos].modified = get_timestamp()
        set_data.modified = get_timestamp()
        save_repo_data(repo_data, repo_root)
        
        local display = new_name or "nickname cleared"
        vim.notify("Bookmark nickname updated: " .. display, vim.log.levels.INFO)
      end)
    end
  end
  
  local function switch_set(items)
    if current_view ~= "sets" or #items == 0 or cursor_pos < 1 or cursor_pos > #items then return end
    
    local item = items[cursor_pos]
    repo_data.current_set = item.name
    update_recent_sets(repo_data, item.name)
    save_repo_data(repo_data, repo_root)
    vim.notify("Switched to set '" .. item.name .. "'", vim.log.levels.INFO)
  end
  
  local function cleanup_action()
    if current_view == "sets" then
      -- Cleanup all sets
      local total_removed = 0
      for set_name, _ in pairs(repo_data.sets) do
        local removed = cleanup_bookmarks(repo_data, set_name)
        total_removed = total_removed + removed
      end
      
      if total_removed > 0 then
        save_repo_data(repo_data, repo_root)
        vim.notify(string.format("Cleaned up %d non-existent bookmarks across all sets", total_removed), vim.log.levels.INFO)
      else
        vim.notify("No cleanup needed - all bookmarks are valid", vim.log.levels.INFO)
      end
    else
      -- Cleanup current set
      local removed = cleanup_bookmarks(repo_data, current_set)
      if removed > 0 then
        save_repo_data(repo_data, repo_root)
        vim.notify(string.format("Cleaned up %d non-existent bookmarks from set '%s'", removed, current_set), vim.log.levels.INFO)
      else
        vim.notify("No cleanup needed - all bookmarks are valid", vim.log.levels.INFO)
      end
    end
  end
  
  local function replace_bookmark_action()
    if current_view ~= "bookmarks" then return end
    
    local current_file = vim.fn.expand("%:p")
    local current_line = vim.fn.line(".")
    
    if current_file == "" then
      vim.notify("No file is currently open", vim.log.levels.WARN)
      return
    end
    
    local set_data = repo_data.sets[current_set]
    if #set_data.bookmarks == 0 then
      vim.notify("No bookmarks to replace", vim.log.levels.WARN)
      return
    end
    
    -- Create selection options
    local options = {}
    for i, bookmark in ipairs(set_data.bookmarks) do
      local display_name = bookmark.nickname or vim.fn.fnamemodify(bookmark.file, ":t")
      local path = format_path(bookmark.file)
      table.insert(options, string.format("%d. %s [%s:%d]", i, display_name, path, bookmark.line))
    end
    
    vim.ui.select(options, {
      prompt = "Replace which bookmark with current location (" .. format_path(current_file) .. ":" .. current_line .. ")?",
    }, function(choice)
      if not choice then return end
      
      local index = tonumber(choice:match("^(%d+)%."))
      if index and set_data.bookmarks[index] then
        local old_bookmark = set_data.bookmarks[index]
        local old_display = (old_bookmark.nickname or vim.fn.fnamemodify(old_bookmark.file, ":t")) .. " [" .. format_path(old_bookmark.file) .. ":" .. old_bookmark.line .. "]"
        
        -- Ask for new nickname
        vim.ui.input({
          prompt = "New bookmark nickname (current: " .. (old_bookmark.nickname or "none") .. "): ",
          default = old_bookmark.nickname or "",
        }, function(new_nickname)
          if new_nickname == nil then return end -- User cancelled
          
          new_nickname = vim.trim(new_nickname)
          if new_nickname == "" then
            new_nickname = nil
          end
          
          -- Update the bookmark with new location and nickname, keep created time
          set_data.bookmarks[index].file = current_file
          set_data.bookmarks[index].line = current_line
          set_data.bookmarks[index].nickname = new_nickname
          set_data.bookmarks[index].modified = get_timestamp()
          set_data.modified = get_timestamp()
          save_repo_data(repo_data, repo_root)
          
          local new_display = (new_nickname or vim.fn.fnamemodify(current_file, ":t")) .. " [" .. format_path(current_file) .. ":" .. current_line .. "]"
          vim.notify("Replaced bookmark: " .. old_display .. " → " .. new_display, vim.log.levels.INFO)
        end)
      end
    end)
  end
  
  local function jump_to_bookmark(items)
    if current_view ~= "bookmarks" or #items == 0 or cursor_pos < 1 or cursor_pos > #items then return end
    
    local item = items[cursor_pos]
    local bookmark = item.bookmark
    
    if vim.fn.filereadable(bookmark.file) == 1 then
      vim.api.nvim_win_close(win, true)
      vim.cmd("edit " .. vim.fn.fnameescape(bookmark.file))
      vim.fn.cursor(bookmark.line, 1)
      vim.cmd("normal! zz")
      
      local display_name = bookmark.nickname or format_path(bookmark.file) .. ":" .. bookmark.line
      vim.notify("Jumped to bookmark: " .. display_name, vim.log.levels.INFO)
    else
      vim.notify("Bookmark file no longer exists: " .. bookmark.file, vim.log.levels.WARN)
    end
  end
  
  local function enter_action(items)
    if current_view == "sets" then
      if #items == 0 or cursor_pos < 1 or cursor_pos > #items then return end
      current_set = items[cursor_pos].name
      current_view = "bookmarks"
      cursor_pos = 1
    else
      jump_to_bookmark(items)
    end
  end
  
  local function back_action()
    if current_view == "bookmarks" then
      current_view = "sets"
      current_set = nil
      cursor_pos = 1
    end
  end
  
  -- Main update loop
  local function refresh()
    -- Check if window and buffer are still valid
    if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
      return {}
    end
    
    repo_data = load_repo_data(repo_root)
    local items = update_buffer()
    return items
  end
  
  -- Setup
  create_window()
  local items = refresh()
  
  -- Set up keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  
  -- Navigation
  vim.keymap.set("n", "j", function()
    move_cursor("down", items)
    items = refresh()
  end, opts)
  
  vim.keymap.set("n", "k", function()
    move_cursor("up", items)
    items = refresh()
  end, opts)
  
  -- Move items
  vim.keymap.set("n", "<C-j>", function()
    move_item("down", items)
    items = refresh()
  end, opts)
  
  vim.keymap.set("n", "<C-k>", function()
    move_item("up", items)
    items = refresh()
  end, opts)
  
  -- Actions
  vim.keymap.set("n", "<CR>", function()
    enter_action(items)
    -- Don't refresh if window was closed
    if vim.api.nvim_win_is_valid(win) then
      items = refresh()
    end
  end, opts)
  
  vim.keymap.set("n", "a", function()
    add_item()
    if vim.api.nvim_win_is_valid(win) then
      items = refresh()
    end
  end, opts)
  
  vim.keymap.set("n", "x", function()
    delete_item(items)
    if vim.api.nvim_win_is_valid(win) then
      items = refresh()
    end
  end, opts)
  
  vim.keymap.set("n", "r", function()
    rename_item(items)
    if vim.api.nvim_win_is_valid(win) then
      items = refresh()
    end
  end, opts)
  
  vim.keymap.set("n", "s", function()
    switch_set(items)
    if vim.api.nvim_win_is_valid(win) then
      items = refresh()
    end
  end, opts)
  
  vim.keymap.set("n", "c", function()
    cleanup_action()
    if vim.api.nvim_win_is_valid(win) then
      items = refresh()
    end
  end, opts)
  
  vim.keymap.set("n", "p", function()
    replace_bookmark_action()
    if vim.api.nvim_win_is_valid(win) then
      items = refresh()
    end
  end, opts)
  
  vim.keymap.set("n", "b", function()
    if current_view == "bookmarks" then
      back_action()
      if vim.api.nvim_win_is_valid(win) then
        items = refresh()
      end
    else
      vim.api.nvim_win_close(win, true)
    end
  end, opts)
  
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  
  -- Auto-close on buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

-- Quick add bookmark function
function M.add_bookmark()
  local current_file = vim.fn.expand("%:p")
  local current_line = vim.fn.line(".")
  
  if current_file == "" then
    vim.notify("No file is currently open", vim.log.levels.WARN)
    return
  end
  
  local repo_root = get_repo_root()
  local repo_data = load_repo_data(repo_root)
  
  vim.ui.input({
    prompt = "Bookmark nickname (optional): ",
    default = "",
  }, function(nickname)
    nickname = nickname and vim.trim(nickname) or ""
    if nickname == "" then
      nickname = nil
    end
    
    local current_set = repo_data.sets[repo_data.current_set]
    
    -- Check if exact bookmark already exists
    for i, bookmark in ipairs(current_set.bookmarks) do
      if bookmark.file == current_file and bookmark.line == current_line then
        bookmark.nickname = nickname
        bookmark.modified = get_timestamp()
        current_set.modified = get_timestamp()
        save_repo_data(repo_data, repo_root)
        vim.notify("Updated bookmark in set '" .. repo_data.current_set .. "'", vim.log.levels.INFO)
        return
      end
    end
    
    -- Add new bookmark
    local bookmark = {
      file = current_file,
      line = current_line,
      nickname = nickname,
      created = get_timestamp(),
      modified = get_timestamp(),
    }
    
    table.insert(current_set.bookmarks, bookmark)
    current_set.modified = get_timestamp()
    save_repo_data(repo_data, repo_root)
    
    local display_name = nickname or format_path(current_file) .. ":" .. current_line
    vim.notify("Added bookmark '" .. display_name .. "' to set '" .. repo_data.current_set .. "'", vim.log.levels.INFO)
  end)
end

-- Jump to bookmark by index (for quick jump keys)
function M.jump_to_bookmark(index)
  local repo_root = get_repo_root()
  local repo_data = load_repo_data(repo_root)
  local current_set = repo_data.sets[repo_data.current_set]
  
  if #current_set.bookmarks == 0 then
    vim.notify("No bookmarks in set '" .. repo_data.current_set .. "'", vim.log.levels.WARN)
    return
  end
  
  if index < 1 or index > #current_set.bookmarks then
    vim.notify("Bookmark " .. index .. " doesn't exist (only " .. #current_set.bookmarks .. " bookmarks available)", vim.log.levels.WARN)
    return
  end
  
  local bookmark = current_set.bookmarks[index]
  if vim.fn.filereadable(bookmark.file) == 1 then
    vim.cmd("edit " .. vim.fn.fnameescape(bookmark.file))
    vim.fn.cursor(bookmark.line, 1)
    vim.cmd("normal! zz")
    
    local display_name = bookmark.nickname or format_path(bookmark.file) .. ":" .. bookmark.line
    vim.notify("Jumped to bookmark " .. index .. ": " .. display_name, vim.log.levels.INFO)
  else
    vim.notify("Bookmark file no longer exists: " .. bookmark.file, vim.log.levels.WARN)
  end
end

-- Quick run function for current set
function M.run_current_set()
  local repo_root = get_repo_root()
  local repo_data = load_repo_data(repo_root)
  
  if not repo_data.current_set then
    vim.notify("No current bookmark set selected. Use the UI to set one.", vim.log.levels.WARN)
    return
  end
  
  local set_data = repo_data.sets[repo_data.current_set]
  if not set_data or not set_data.bookmarks or #set_data.bookmarks == 0 then
    vim.notify("No bookmarks in current set '" .. repo_data.current_set .. "'", vim.log.levels.WARN)
    return
  end
  
  if #set_data.bookmarks == 1 then
    local bookmark = set_data.bookmarks[1]
    if vim.fn.filereadable(bookmark.file) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(bookmark.file))
      vim.fn.cursor(bookmark.line, 1)
      vim.cmd("normal! zz")
      
      local display_name = bookmark.nickname or format_path(bookmark.file) .. ":" .. bookmark.line
      vim.notify("Jumped to bookmark: " .. display_name, vim.log.levels.INFO)
    else
      vim.notify("Bookmark file no longer exists: " .. bookmark.file, vim.log.levels.WARN)
    end
    return
  end
  
  -- Multiple bookmarks, show selection
  local options = {}
  for i, bookmark in ipairs(set_data.bookmarks) do
    local display_name = bookmark.nickname or vim.fn.fnamemodify(bookmark.file, ":t")
    local path = format_path(bookmark.file)
    table.insert(options, string.format("%d. %s [%s:%d]", i, display_name, path, bookmark.line))
  end
  
  vim.ui.select(options, {
    prompt = "Jump to bookmark from set '" .. repo_data.current_set .. "':",
  }, function(choice)
    if not choice then return end
    
    local index = tonumber(choice:match("^(%d+)%."))
    if index and set_data.bookmarks[index] then
      local bookmark = set_data.bookmarks[index]
      if vim.fn.filereadable(bookmark.file) == 1 then
        vim.cmd("edit " .. vim.fn.fnameescape(bookmark.file))
        vim.fn.cursor(bookmark.line, 1)
        vim.cmd("normal! zz")
        
        local display_name = bookmark.nickname or format_path(bookmark.file) .. ":" .. bookmark.line
        vim.notify("Jumped to bookmark: " .. display_name, vim.log.levels.INFO)
      else
        vim.notify("Bookmark file no longer exists: " .. bookmark.file, vim.log.levels.WARN)
      end
    end
  end)
end

-- Replace existing bookmark with current location
function M.replace_bookmark()
  local current_file = vim.fn.expand("%:p")
  local current_line = vim.fn.line(".")
  
  if current_file == "" then
    vim.notify("No file is currently open", vim.log.levels.WARN)
    return
  end
  
  local repo_root = get_repo_root()
  local repo_data = load_repo_data(repo_root)
  local current_set = repo_data.sets[repo_data.current_set]
  
  if #current_set.bookmarks == 0 then
    vim.notify("No bookmarks in current set to replace", vim.log.levels.WARN)
    return
  end
  
  -- Create selection options
  local options = {}
  for i, bookmark in ipairs(current_set.bookmarks) do
    local display_name = bookmark.nickname or vim.fn.fnamemodify(bookmark.file, ":t")
    local path = format_path(bookmark.file)
    table.insert(options, string.format("%d. %s [%s:%d]", i, display_name, path, bookmark.line))
  end
  
  vim.ui.select(options, {
    prompt = "Replace which bookmark with current location (" .. format_path(current_file) .. ":" .. current_line .. ")?",
  }, function(choice)
    if not choice then return end
    
    local index = tonumber(choice:match("^(%d+)%."))
    if index and current_set.bookmarks[index] then
      local old_bookmark = current_set.bookmarks[index]
      local old_display = (old_bookmark.nickname or vim.fn.fnamemodify(old_bookmark.file, ":t")) .. " [" .. format_path(old_bookmark.file) .. ":" .. old_bookmark.line .. "]"
      
      -- Ask for new nickname
      vim.ui.input({
        prompt = "New bookmark nickname (current: " .. (old_bookmark.nickname or "none") .. "): ",
        default = old_bookmark.nickname or "",
      }, function(new_nickname)
        if new_nickname == nil then return end -- User cancelled
        
        new_nickname = vim.trim(new_nickname)
        if new_nickname == "" then
          new_nickname = nil
        end
        
        -- Update the bookmark with new location and nickname, keep created time
        current_set.bookmarks[index].file = current_file
        current_set.bookmarks[index].line = current_line
        current_set.bookmarks[index].nickname = new_nickname
        current_set.bookmarks[index].modified = get_timestamp()
        current_set.modified = get_timestamp()
        save_repo_data(repo_data, repo_root)
        
        local new_display = (new_nickname or vim.fn.fnamemodify(current_file, ":t")) .. " [" .. format_path(current_file) .. ":" .. current_line .. "]"
        vim.notify("Replaced bookmark: " .. old_display .. " → " .. new_display, vim.log.levels.INFO)
      end)
    end
  end)
end

-- Setup function
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", default_config, user_config or {})
  
  -- Ensure data directory exists
  if vim.fn.isdirectory(config.data_dir) == 0 then
    vim.fn.mkdir(config.data_dir, "p")
  end
  
  -- Create user commands
  vim.api.nvim_create_user_command("BookmarkManager", function()
    M.show_ui()
  end, { desc = "Open Bookmark Manager UI" })
  
  vim.api.nvim_create_user_command("BookmarkAdd", function()
    M.add_bookmark()
  end, { desc = "Add bookmark to current set" })
  
  vim.api.nvim_create_user_command("BookmarkJump", function()
    M.run_current_set()
  end, { desc = "Jump to bookmark from current set" })
  
  vim.api.nvim_create_user_command("BookmarkReplace", function()
    M.replace_bookmark()
  end, { desc = "Replace existing bookmark with current location" })
  
  -- Set up keymaps with descriptions
  vim.keymap.set("n", "<leader>bm", M.show_ui, { 
    noremap = true, 
    silent = true, 
    desc = "Bookmark Manager" 
  })
  
  vim.keymap.set("n", "<leader>ba", M.add_bookmark, { 
    noremap = true, 
    silent = true, 
    desc = "Add bookmark to current set" 
  })
  
  vim.keymap.set("n", "<leader>bb", M.run_current_set, { 
    noremap = true, 
    silent = true, 
    desc = "Jump to bookmark from current set" 
  })
  
  vim.keymap.set("n", "<leader>bp", M.replace_bookmark, { 
    noremap = true, 
    silent = true, 
    desc = "Replace existing bookmark with current location" 
  })
  
  -- Set up quick jump keys if enabled
  if config.enable_numbered_jumps then
    for i, key in ipairs(config.quick_jump_keys) do
      vim.keymap.set("n", "\\" .. key, function() M.jump_to_bookmark(i) end, { 
        noremap = true, 
        silent = true, 
        desc = "Jump to bookmark #" .. i .. " (\\" .. key .. ") in current set" 
      })
      
      vim.api.nvim_create_user_command("BookmarkJump" .. key:upper(), function() M.jump_to_bookmark(i) end, { 
        desc = "Jump to bookmark #" .. i .. " (\\" .. key .. ") in current set" 
      })
    end
  end
end

return M 