local M = {}

-- Get the git root directory
local function get_git_root()
  local handle = io.popen("git rev-parse --show-toplevel 2>/dev/null")
  if handle then
    local result = handle:read("*a"):gsub("%s+", "")
    handle:close()
    if result and result ~= "" then
      return result
    end
  end
  return vim.fn.getcwd()
end

-- Get the git repo key (directory name)
local function get_repo_key()
  local git_root = get_git_root()
  return vim.fn.fnamemodify(git_root, ":t")
end

-- Get the debug commands file path in data directory
local function get_commands_file()
  local data_dir = vim.fn.stdpath("data") .. "/debug-commands"
  vim.fn.mkdir(data_dir, "p")
  return data_dir .. "/commands.json"
end

-- Load all debug commands from file
local function load_all_commands()
  local file_path = get_commands_file()
  local file = io.open(file_path, "r")
  if not file then
    return {}
  end
  
  local content = file:read("*a")
  file:close()
  
  local ok, data = pcall(vim.json.decode, content)
  if ok and data then
    return data
  end
  return {}
end

-- Load debug commands for current repository
local function load_commands()
  local all_commands = load_all_commands()
  local repo_key = get_repo_key()
  return all_commands[repo_key] or {}
end

-- Save all debug commands to file
local function save_all_commands(all_commands)
  local file_path = get_commands_file()
  local content = vim.json.encode(all_commands)
  
  local file = io.open(file_path, "w")
  if file then
    file:write(content)
    file:close()
    return true
  end
  return false
end

-- Save debug commands for current repository
local function save_commands(commands)
  local all_commands = load_all_commands()
  local repo_key = get_repo_key()
  all_commands[repo_key] = commands
  return save_all_commands(all_commands)
end

-- File path completion function
local function complete_path(arg_lead)
  local matches = {}
  local pattern = arg_lead .. "*"
  
  -- Get files and directories matching the pattern
  local items = vim.fn.glob(pattern, false, true)
  
  for _, item in ipairs(items) do
    -- Add trailing slash for directories
    if vim.fn.isdirectory(item) == 1 then
      table.insert(matches, item .. "/")
    else
      table.insert(matches, item)
    end
  end
  
  return matches
end

-- Enhanced UI for adding debug commands
function M.add_command_ui()
  vim.ui.input({
    prompt = "Command name: ",
  }, function(name)
    if not name or name == "" then
      return
    end
    
    vim.ui.input({
      prompt = "Command (path): ",
      completion = "file",
    }, function(command)
      if not command or command == "" then
        return
      end
      
      M.add_command(name, command)
    end)
  end)
end

-- Add a new debug command
function M.add_command(name, command)
  if not name or name == "" then
    vim.notify("Debug command name cannot be empty", vim.log.levels.ERROR)
    return
  end
  
  local commands = load_commands()
  
  -- Default to lldb if no debugger specified
  if not command:match("^%w+%s") then
    command = "lldb " .. command
  end
  
  commands[name] = command
  
  if save_commands(commands) then
    vim.notify("Debug command '" .. name .. "' saved: " .. command, vim.log.levels.INFO)
  else
    vim.notify("Failed to save debug command", vim.log.levels.ERROR)
  end
end

-- Enhanced UI for listing and managing debug commands
function M.manage_commands_ui()
  local commands = load_commands()
  local repo_key = get_repo_key()
  
  if vim.tbl_isempty(commands) then
    vim.notify("No debug commands saved for repository: " .. repo_key, vim.log.levels.INFO)
    M.add_command_ui()
    return
  end
  
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = math.min(80, vim.o.columns - 4),
    height = math.min(20, vim.o.lines - 4),
    col = math.floor((vim.o.columns - math.min(80, vim.o.columns - 4)) / 2),
    row = math.floor((vim.o.lines - math.min(20, vim.o.lines - 4)) / 2),
    style = "minimal",
    border = "rounded",
    title = " Debug Commands - " .. repo_key .. " ",
    title_pos = "center",
  })
  
  -- Set window background to match normal background
  vim.api.nvim_win_set_option(win, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
  
  -- Prepare the content
  local command_names = vim.tbl_keys(commands)
  table.sort(command_names)
  
  local lines = {}
  local command_list = {}
  
  -- Header
  table.insert(lines, "")
  table.insert(lines, "  ▶ Press ENTER to run, 'a' to add, 'x' to delete, 'q' to quit")
  table.insert(lines, "")
  table.insert(lines, string.rep("─", 76))
  
  -- Commands
  for i, name in ipairs(command_names) do
    local command = commands[name]
    local display_cmd = command
    if #command > 50 then
      display_cmd = command:sub(1, 47) .. "..."
    end
    
    table.insert(lines, string.format("  %2d. %-20s → %s", i, name, display_cmd))
    table.insert(command_list, { name = name, command = command })
  end
  
  table.insert(lines, "")
  table.insert(lines, string.rep("─", 76))
  table.insert(lines, "  Commands: ENTER=run  a=add  x=delete  q=quit  j/k=navigate")
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "debug-commands")
  
  -- Set cursor to first command (line 5, since we have header)
  local first_cmd_line = 5
  if #command_list > 0 then
    vim.api.nvim_win_set_cursor(win, { first_cmd_line, 2 })
  end
  
  -- Helper function to get current selection
  local function get_current_selection()
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
    local cmd_index = cursor_line - first_cmd_line + 1
    if cmd_index >= 1 and cmd_index <= #command_list then
      return command_list[cmd_index]
    end
    return nil
  end
  
  -- Helper function to refresh the buffer
  local function refresh_buffer()
    local current_commands = load_commands()
    if vim.tbl_isempty(current_commands) then
      vim.api.nvim_win_close(win, true)
      return
    end
    
    local new_command_names = vim.tbl_keys(current_commands)
    table.sort(new_command_names)
    
    local new_lines = {}
    local old_cursor_pos = vim.api.nvim_win_get_cursor(win)[1]
    command_list = {}
    
    -- Header
    table.insert(new_lines, "")
    table.insert(new_lines, "  ▶ Press ENTER to run, 'a' to add, 'x' to delete, 'q' to quit")
    table.insert(new_lines, "")
    table.insert(new_lines, string.rep("─", 76))
    
    -- Commands
    for i, name in ipairs(new_command_names) do
      local command = current_commands[name]
      local display_cmd = command
      if #command > 50 then
        display_cmd = command:sub(1, 47) .. "..."
      end
      
      table.insert(new_lines, string.format("  %2d. %-20s → %s", i, name, display_cmd))
      table.insert(command_list, { name = name, command = command })
    end
    
    table.insert(new_lines, "")
    table.insert(new_lines, string.rep("─", 76))
    table.insert(new_lines, "  Commands: ENTER=run  a=add  x=delete  q=quit  j/k=navigate")
    
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    
    -- Restore cursor position, but ensure it's within bounds
    local max_line = first_cmd_line + #command_list - 1
    local new_cursor_pos = math.min(old_cursor_pos, max_line)
    new_cursor_pos = math.max(new_cursor_pos, first_cmd_line)
    vim.api.nvim_win_set_cursor(win, { new_cursor_pos, 2 })
  end
  
  -- Enhanced add command function that refreshes immediately
  local function add_command_and_refresh()
    vim.ui.input({
      prompt = "Command name: ",
    }, function(name)
      if not name or name == "" then
        return
      end
      
      vim.ui.input({
        prompt = "Command (path): ",
        completion = "file",
      }, function(command)
        if not command or command == "" then
          return
        end
        
        M.add_command(name, command)
        -- Refresh immediately after adding
        if vim.api.nvim_win_is_valid(win) then
          refresh_buffer()
        end
      end)
    end)
  end
  
  -- Keymaps
  local opts = { noremap = true, silent = true, buffer = buf }
  
  -- Navigation
  vim.keymap.set("n", "j", function()
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
    local max_line = first_cmd_line + #command_list - 1
    if cursor_line < max_line then
      vim.api.nvim_win_set_cursor(win, { cursor_line + 1, 2 })
    end
  end, opts)
  
  vim.keymap.set("n", "k", function()
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
    if cursor_line > first_cmd_line then
      vim.api.nvim_win_set_cursor(win, { cursor_line - 1, 2 })
    end
  end, opts)
  
  -- Actions
  vim.keymap.set("n", "<CR>", function()
    local selection = get_current_selection()
    if selection then
      vim.api.nvim_win_close(win, true)
      M.run_command(selection.name)
    end
  end, opts)
  
  vim.keymap.set("n", "a", add_command_and_refresh, opts)
  
  vim.keymap.set("n", "x", function()
    local selection = get_current_selection()
    if selection then
      vim.ui.input({
        prompt = "Delete '" .. selection.name .. "'? (y/N): ",
      }, function(confirm)
        if confirm and confirm:lower():match("^y") then
          M.delete_command(selection.name)
          refresh_buffer()
        end
      end)
    end
  end, opts)
  
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, opts)
  
  vim.keymap.set("n", "<Esc>", function()
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

-- Enhanced UI for deleting commands
function M.delete_command_ui()
  local commands = load_commands()
  
  if vim.tbl_isempty(commands) then
    vim.notify("No debug commands to delete", vim.log.levels.INFO)
    return
  end
  
  local command_names = vim.tbl_keys(commands)
  table.sort(command_names)
  
  local options = {}
  for _, name in ipairs(command_names) do
    table.insert(options, name .. " → " .. commands[name])
  end
  
  vim.ui.select(options, {
    prompt = "Delete debug command:",
  }, function(choice)
    if not choice then
      return
    end
    
    local name = choice:match("^([^→]+)")
    if name then
      name = vim.trim(name)
      vim.ui.input({
        prompt = "Delete '" .. name .. "'? (y/N): ",
      }, function(confirm)
        if confirm and confirm:lower():match("^y") then
          M.delete_command(name)
        end
      end)
    end
  end)
end

-- List all debug commands
function M.list_commands()
  local commands = load_commands()
  local repo_key = get_repo_key()
  
  if vim.tbl_isempty(commands) then
    vim.notify("No debug commands saved for repository: " .. repo_key, vim.log.levels.INFO)
    return
  end
  
  local lines = { "Debug commands for " .. repo_key .. ":" }
  for name, command in pairs(commands) do
    table.insert(lines, "  " .. name .. ": " .. command)
  end
  
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Run a debug command
function M.run_command(name)
  local commands = load_commands()
  local command = commands[name]
  
  if not command then
    vim.notify("Debug command '" .. name .. "' not found", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Running: Termdbg " .. command, vim.log.levels.INFO)
  vim.cmd("Termdbg " .. command)
end

-- Delete a debug command
function M.delete_command(name)
  local commands = load_commands()
  
  if not commands[name] then
    vim.notify("Debug command '" .. name .. "' not found", vim.log.levels.ERROR)
    return
  end
  
  commands[name] = nil
  
  if save_commands(commands) then
    vim.notify("Debug command '" .. name .. "' deleted", vim.log.levels.INFO)
  else
    vim.notify("Failed to delete debug command", vim.log.levels.ERROR)
  end
end

-- Enhanced UI for selecting and running commands
function M.run_command_ui()
  local commands = load_commands()
  
  if vim.tbl_isempty(commands) then
    vim.notify("No debug commands saved. Use :DebugAdd to create one.", vim.log.levels.WARN)
    return
  end
  
  local command_names = vim.tbl_keys(commands)
  table.sort(command_names)
  
  local options = {}
  for _, name in ipairs(command_names) do
    table.insert(options, name .. " → " .. commands[name])
  end
  
  vim.ui.select(options, {
    prompt = "Run debug command:",
  }, function(choice)
    if not choice then
      return
    end
    
    local name = choice:match("^([^→]+)")
    if name then
      name = vim.trim(name)
      M.run_command(name)
    end
  end)
end

-- Get command names for completion
function M.get_command_names()
  local commands = load_commands()
  return vim.tbl_keys(commands)
end

-- Setup the plugin
function M.setup()
  -- Create user commands
  vim.api.nvim_create_user_command("DebugAdd", function(opts)
    if opts.args == "" then
      M.add_command_ui()
      return
    end
    
    local args = vim.split(opts.args, " ", { trimempty = true })
    if #args < 2 then
      vim.notify("Usage: :DebugAdd <name> <command> or :DebugAdd (for UI)", vim.log.levels.ERROR)
      return
    end
    
    local name = args[1]
    local command = table.concat(vim.list_slice(args, 2), " ")
    M.add_command(name, command)
  end, { 
    nargs = "*", 
    desc = "Add debug command (with UI if no args)",
    complete = function(arg_lead, cmd_line, cursor_pos)
      local args = vim.split(cmd_line, " ", { trimempty = true })
      if #args >= 3 then
        -- Complete file paths for the command part
        return complete_path(arg_lead)
      end
      return {}
    end
  })
  
  vim.api.nvim_create_user_command("DebugManage", function()
    M.manage_commands_ui()
  end, { desc = "Manage debug commands (UI)" })
  
  vim.api.nvim_create_user_command("DebugList", function()
    M.list_commands()
  end, { desc = "List debug commands" })
  
  vim.api.nvim_create_user_command("DebugRun", function(opts)
    if opts.args == "" then
      M.run_command_ui()
      return
    end
    M.run_command(opts.args)
  end, {
    nargs = "?",
    complete = function()
      return M.get_command_names()
    end,
    desc = "Run debug command (with UI if no args)"
  })
  
  vim.api.nvim_create_user_command("DebugDelete", function(opts)
    if opts.args == "" then
      M.delete_command_ui()
      return
    end
    M.delete_command(opts.args)
  end, {
    nargs = "?",
    complete = function()
      return M.get_command_names()
    end,
    desc = "Delete debug command (with UI if no args)"
  })
  
  -- Add keymap for quick debug command runner
  vim.keymap.set("n", "<leader>dr", M.run_command_ui, { desc = "Run debug command (UI)" })
  vim.keymap.set("n", "<leader>dm", M.manage_commands_ui, { desc = "Manage debug commands (UI)" })
  vim.keymap.set("n", "<leader>da", M.add_command_ui, { desc = "Add debug command (UI)" })
end

return M
