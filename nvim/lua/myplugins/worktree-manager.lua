-- Worktree Manager Plugin
-- Provides a UI for managing git worktrees

local M = {}

-- State for the worktree manager
local state = {
  buf = nil,
  win = nil,
  worktrees = {},
  current_line = 1,
}

-- Get all worktrees
local function get_worktrees()
  local result = vim.fn.system("git worktree list --porcelain")
  if vim.v.shell_error ~= 0 then
    vim.notify("Error getting worktrees: " .. result, vim.log.levels.ERROR)
    return {}
  end

  local worktrees = {}
  local current_worktree = {}
  
  for line in result:gmatch("[^\r\n]+") do
    if line:match("^worktree ") then
      if current_worktree.path then
        table.insert(worktrees, current_worktree)
      end
      current_worktree = {
        path = line:gsub("^worktree ", ""),
        branch = nil,
        head = nil,
        bare = false,
      }
    elseif line:match("^HEAD ") then
      current_worktree.head = line:gsub("^HEAD ", "")
    elseif line:match("^branch ") then
      current_worktree.branch = line:gsub("^branch refs/heads/", "")
    elseif line:match("^bare") then
      current_worktree.bare = true
    end
  end
  
  -- Add the last worktree
  if current_worktree.path then
    table.insert(worktrees, current_worktree)
  end
  
  return worktrees
end

-- Create the UI content
local function create_content()
  local lines = {}
  local header = "Git Worktrees (j/k: navigate, x: delete, <Enter>: switch, q: quit)"
  if vim.env.TMUX then
    header = "Git Worktrees (j/k: navigate, x: delete, <Enter>: tmux switch, q: quit, 🔗: has session)"
  end
  table.insert(lines, header)
  table.insert(lines, string.rep("─", #header))
  table.insert(lines, "")
  
  -- Only refresh worktrees if we don't have them cached
  if #state.worktrees == 0 then
    state.worktrees = get_worktrees()
  end
  
  if #state.worktrees == 0 then
    table.insert(lines, "No worktrees found")
    return lines
  end
  
  for i, worktree in ipairs(state.worktrees) do
    local branch_info = worktree.branch or "detached"
    if worktree.bare then
      branch_info = branch_info .. " (bare)"
    end
    
    local current_marker = ""
    local current_dir = vim.fn.getcwd()
    if current_dir == worktree.path then
      current_marker = " ← current"
    end
    
    -- Check if tmux session exists for this worktree
    local tmux_info = ""
    if vim.env.TMUX then
      local session_name = vim.fn.fnamemodify(worktree.path, ":t"):gsub("%.", "_")
      local has_session_cmd = string.format("tmux has-session -t=%s", session_name)
      vim.fn.system(has_session_cmd)
      if vim.v.shell_error == 0 then
        tmux_info = " 🔗"
      end
    end
    
    local line = string.format("  %s [%s]%s%s", worktree.path, branch_info, tmux_info, current_marker)
    table.insert(lines, line)
  end
  
  return lines
end

-- Update the display
local function update_display()
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  
  -- Temporarily make buffer modifiable
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)
  
  local lines = create_content()
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  
  -- Make buffer not modifiable again
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
  
  -- Set cursor position (accounting for header lines: header + separator + empty = 3 lines)
  if #state.worktrees > 0 then
    local line_num = state.current_line + 3 -- +3 for header, separator, and empty line
    line_num = math.min(line_num, #lines)
    line_num = math.max(line_num, 4) -- Ensure we're at least on the first worktree line
    if vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_set_cursor(state.win, {line_num, 0})
    end
  end
end

-- Get selected worktree
local function get_selected_worktree()
  if #state.worktrees == 0 then
    return nil
  end
  
  local idx = state.current_line
  if idx < 1 or idx > #state.worktrees then
    return nil
  end
  
  return state.worktrees[idx]
end

-- Switch to selected worktree
local function switch_to_worktree()
  local worktree = get_selected_worktree()
  if not worktree then
    vim.notify("No worktree selected", vim.log.levels.WARN)
    return
  end
  
  M.close_ui()
  
  -- Check if we're in tmux
  if not vim.env.TMUX then
    -- Fallback to simple cd if not in tmux
    vim.cmd("cd " .. worktree.path)
    vim.notify("Switched to worktree: " .. worktree.path, vim.log.levels.INFO)
    return
  end
  
  -- Generate session name from worktree path (similar to ta() function)
  local selected_name = vim.fn.fnamemodify(worktree.path, ":t"):gsub("%.", "_")
  
  -- Check if tmux session exists, create if not
  local has_session_cmd = string.format("tmux has-session -t=%s", selected_name)
  local session_exists = vim.fn.system(has_session_cmd)
  
  if vim.v.shell_error ~= 0 then
    -- Session doesn't exist, create it
    local new_session_cmd = string.format("tmux new-session -ds %s -c %s", selected_name, worktree.path)
    local create_result = vim.fn.system(new_session_cmd)
    
    if vim.v.shell_error == 0 then
      -- First update submodules, then start vim in the new session
      local submodule_cmd = string.format("tmux send-keys -t %s 'git submodule update --init --recursive --jobs 8 && vim .' Enter", selected_name)
      vim.fn.system(submodule_cmd)
    else
      vim.notify("Failed to create tmux session: " .. create_result, vim.log.levels.ERROR)
      return
    end
  end
  
  -- Switch to the session
  local switch_cmd = string.format("tmux switch-client -t %s", selected_name)
  local switch_result = vim.fn.system(switch_cmd)
  
  if vim.v.shell_error == 0 then
    vim.notify("Switched to tmux session: " .. selected_name, vim.log.levels.INFO)
  else
    vim.notify("Failed to switch to tmux session: " .. switch_result, vim.log.levels.ERROR)
  end
end

-- Delete selected worktree
local function delete_worktree()
  local worktree = get_selected_worktree()
  if not worktree then
    vim.notify("No worktree selected", vim.log.levels.WARN)
    return
  end
  
  -- Don't allow deleting the current worktree
  local current_dir = vim.fn.getcwd()
  if current_dir == worktree.path then
    vim.notify("Cannot delete current worktree", vim.log.levels.WARN)
    return
  end
  
  -- Confirm deletion
  local branch_info = worktree.branch or "detached"
  local confirm = vim.fn.confirm(
    string.format("Delete worktree:\n%s [%s]?", worktree.path, branch_info),
    "&Yes\n&No",
    2
  )
  
  if confirm ~= 1 then
    return
  end
  
  -- Delete the worktree
  local cmd = string.format("git worktree remove %s", worktree.path)
  local result = vim.fn.system(cmd)
  
  if vim.v.shell_error == 0 then
    vim.notify("Deleted worktree: " .. worktree.path, vim.log.levels.INFO)
    
    -- Delete associated tmux session if it exists
    if vim.env.TMUX then
      local session_name = vim.fn.fnamemodify(worktree.path, ":t"):gsub("%.", "_")
      local has_session_cmd = string.format("tmux has-session -t=%s", session_name)
      vim.fn.system(has_session_cmd)
      
      if vim.v.shell_error == 0 then
        -- Session exists, kill it
        local kill_session_cmd = string.format("tmux kill-session -t %s", session_name)
        local kill_result = vim.fn.system(kill_session_cmd)
        
        if vim.v.shell_error == 0 then
          vim.notify("Deleted tmux session: " .. session_name, vim.log.levels.INFO)
        else
          vim.notify("Failed to delete tmux session: " .. kill_result, vim.log.levels.WARN)
        end
      end
    end
    
    -- Refresh worktree list and update display
    state.worktrees = get_worktrees()
    
    -- Adjust current line if needed
    if state.current_line > #state.worktrees then
      state.current_line = math.max(1, #state.worktrees)
    end
    
    update_display()
  else
    vim.notify("Failed to delete worktree: " .. result, vim.log.levels.ERROR)
  end
end

-- Navigate up
local function navigate_up()
  if state.current_line > 1 then
    state.current_line = state.current_line - 1
    update_display()
  end
end

-- Navigate down
local function navigate_down()
  if state.current_line < #state.worktrees then
    state.current_line = state.current_line + 1
    update_display()
  end
end

-- Setup buffer keymaps
local function setup_keymaps()
  local opts = { buffer = state.buf, silent = true, nowait = true }
  
  -- Navigation
  vim.keymap.set('n', 'j', navigate_down, opts)
  vim.keymap.set('n', 'k', navigate_up, opts)
  vim.keymap.set('n', '<Down>', navigate_down, opts)
  vim.keymap.set('n', '<Up>', navigate_up, opts)
  
  -- Actions
  vim.keymap.set('n', '<CR>', switch_to_worktree, opts)
  vim.keymap.set('n', '<Space>', switch_to_worktree, opts)
  vim.keymap.set('n', 'x', delete_worktree, opts)
  vim.keymap.set('n', 'd', delete_worktree, opts)
  vim.keymap.set('n', '<Del>', delete_worktree, opts)
  
  -- Close
  vim.keymap.set('n', 'q', M.close_ui, opts)
  vim.keymap.set('n', '<Esc>', M.close_ui, opts)
  vim.keymap.set('n', '<C-c>', M.close_ui, opts)
  
  -- Refresh
  vim.keymap.set('n', 'r', update_display, opts)
  vim.keymap.set('n', '<F5>', update_display, opts)
end

-- Close the UI
function M.close_ui()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf = nil
  state.win = nil
end

-- Show worktrees UI
function M.show_worktrees()
  -- Close existing UI if open
  M.close_ui()
  
  -- Get worktrees first to determine initial position
  local worktrees = get_worktrees()
  state.worktrees = worktrees
  
  -- Find current worktree index
  local current_dir = vim.fn.getcwd()
  local current_index = 1
  for i, worktree in ipairs(worktrees) do
    if current_dir == worktree.path then
      current_index = i
      break
    end
  end
  
  -- Set initial state
  state.current_line = current_index
  
  -- Create buffer
  state.buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(state.buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(state.buf, 'filetype', 'worktree-manager')
  vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
  vim.api.nvim_buf_set_name(state.buf, 'Worktree Manager')
  
  -- Calculate window size
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.6)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)
  
  -- Create floating window
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' Worktree Manager ',
    title_pos = 'center',
  })
  
  -- Set window options
  vim.api.nvim_win_set_option(state.win, 'cursorline', true)
  vim.api.nvim_win_set_option(state.win, 'wrap', false)
  
  -- Setup keymaps
  setup_keymaps()
  
  -- Initial display
  update_display()
  
  -- Auto-close on buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.buf,
    once = true,
    callback = function()
      vim.defer_fn(function()
        M.close_ui()
      end, 100)
    end,
  })
end

-- Add a new worktree
function M.add_worktree()
  -- Get current repository name
  local repo_root = vim.fn.system("git rev-parse --show-toplevel"):gsub('\n', '')
  if vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return
  end
  
  local repo_name = vim.fn.fnamemodify(repo_root, ":t")
  
  -- Prompt for branch name
  local branch_name = vim.fn.input("Branch name for new worktree: ")
  if branch_name == "" then
    return
  end
  
  -- Sanitize branch name for directory
  local sanitized_branch = branch_name:gsub("[^%w%-]", "_")
  
  -- Default path
  local default_path = vim.fn.expand("~/repos/" .. repo_name .. "_" .. sanitized_branch)
  local worktree_path = vim.fn.input("Worktree path: ", default_path)
  
  if worktree_path == "" then
    return
  end
  
  -- Check if directory already exists
  if vim.fn.isdirectory(worktree_path) == 1 then
    vim.notify("Directory already exists: " .. worktree_path, vim.log.levels.ERROR)
    return
  end
  
  -- Create the worktree
  local cmd = string.format("git worktree add %s %s", worktree_path, branch_name)
  local result = vim.fn.system(cmd)
  
  if vim.v.shell_error == 0 then
    vim.notify("Created worktree: " .. worktree_path, vim.log.levels.INFO)
    
    -- Ask if user wants to switch to the new worktree
    local switch = vim.fn.confirm("Switch to new worktree?", "&Yes\n&No", 1)
    if switch == 1 then
      -- Check if we're in tmux
      if vim.env.TMUX then
        -- Generate session name from worktree path
        local selected_name = vim.fn.fnamemodify(worktree_path, ":t"):gsub("%.", "_")
        
        -- Create tmux session
        local new_session_cmd = string.format("tmux new-session -ds %s -c %s", selected_name, worktree_path)
        local create_result = vim.fn.system(new_session_cmd)
        
        if vim.v.shell_error == 0 then
          -- First update submodules, then start vim in the new session
          local submodule_cmd = string.format("tmux send-keys -t %s 'git submodule update --init --recursive --jobs 8 && vim .' Enter", selected_name)
          vim.fn.system(submodule_cmd)
          
          -- Switch to the session (only switch tmux, don't change current pwd)
          local switch_cmd = string.format("tmux switch-client -t %s", selected_name)
          local switch_result = vim.fn.system(switch_cmd)
          
          if vim.v.shell_error == 0 then
            vim.notify("Switched to tmux session: " .. selected_name, vim.log.levels.INFO)
          else
            vim.notify("Failed to switch to tmux session: " .. switch_result, vim.log.levels.ERROR)
          end
        else
          vim.notify("Failed to create tmux session: " .. create_result, vim.log.levels.ERROR)
        end
      else
        -- If not in tmux, just notify that the worktree was created
        vim.notify("Worktree created. Not in tmux, so staying in current directory.", vim.log.levels.INFO)
      end
    end
  else
    vim.notify("Failed to create worktree: " .. result, vim.log.levels.ERROR)
  end
end

return M 