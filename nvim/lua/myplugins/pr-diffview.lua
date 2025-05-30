-- PR Comment Integration for Diffview
-- Phase 1: Basic comment posting
-- Phase 2: Comment viewing with profile pictures and sign column indicators

local M = {}

-- Configuration
M.config = {
  enable = true,
  gh_path = "gh",
  cache_dir = vim.fn.stdpath("cache") .. "/pr_comments",
  auto_detect_pr = true,
  
  -- Phase 2: Sign column and image settings
  sign_column = {
    enable = true,
    sign_name = "PRComment",
    text = "💬",
    texthl = "DiagnosticSignInfo",
    numhl = "DiagnosticSignInfo",
  },
  
  -- Image display settings (for Phase 2)
  profile_pic_size = { width = 10, height = 10 },
  show_profile_pics = true,
  max_comment_width = 80,
  
  -- Comment window settings
  floating_window = {
    border = "rounded",
    title = " PR Comments ",
    max_height = 20,
    max_width = 100,
  },
  
  -- Auto-preview settings
  auto_preview = {
    enable = false,  -- Toggle for auto-showing comments when cursor moves to commented lines
    delay_ms = 150,  -- Delay before showing/hiding to avoid flicker
  }
}

-- State management
local state = {
  current_pr = nil,
  comments_cache = {},
  profile_pics_cache = {},  -- Keep for future implementation
  repo_info = nil,
  
  -- Auto-preview state
  auto_preview = {
    current_win = nil,     -- Currently open comment window
    current_buf = nil,     -- Currently open comment buffer  
    current_line = nil,    -- Line number for current preview
    current_file = nil,    -- File path for current preview
    timer = nil,           -- Timer for delayed show/hide
    creating = false,      -- Flag to prevent closing during creation
    layout_saved = false,  -- Whether we've saved the original layout
    sidebar_was_open = false, -- Whether sidebar was open before preview
    original_window = nil, -- Store original window to restore focus
    is_explicit = false,   -- Whether this is an explicit view (vs auto-preview)
    saved_auto_state = nil, -- Store the original auto-preview enable state when opening explicit view
  }
}

-- Phase 1: Core Functions

-- Get the cache file path for branch-to-PR mapping
function M.get_branch_pr_cache_path()
  return M.config.cache_dir .. "/branch_pr_mapping.json"
end

-- Get current repository identifier (owner/repo format)
function M.get_repository_identifier()
  local repo_info = M.get_repo_info()
  if not repo_info then
    return nil
  end
  return repo_info.owner .. "/" .. repo_info.name
end

-- Load branch-to-PR mapping from cache file
function M.load_branch_pr_cache()
  local cache_file = M.get_branch_pr_cache_path()
  
  if vim.fn.filereadable(cache_file) == 0 then
    return { repositories = {} }
  end
  
  local handle = io.open(cache_file, "r")
  if not handle then
    return { repositories = {} }
  end
  
  local content = handle:read("*a")
  handle:close()
  
  if content == "" then
    return { repositories = {} }
  end
  
  local success, data = pcall(vim.json.decode, content)
  if not success or not data then
    return { repositories = {} }
  end
  
  -- Migrate old format to new format if needed
  if data.branch_to_pr and not data.repositories then
    return { repositories = {} }  -- Reset old format, too complex to migrate
  end
  
  -- Ensure repositories structure exists
  if not data.repositories then
    data.repositories = {}
  end
  
  return data
end

-- Save branch-to-PR mapping to cache file
function M.save_branch_pr_cache(cache_data)
  local cache_file = M.get_branch_pr_cache_path()
  
  -- Ensure the cache directory exists
  vim.fn.mkdir(M.config.cache_dir, "p")
  
  local handle = io.open(cache_file, "w")
  if not handle then
    vim.notify("Failed to save branch-PR cache", vim.log.levels.ERROR)
    return false
  end
  
  local json_data = vim.json.encode(cache_data)
  handle:write(json_data)
  handle:close()
  
  return true
end

-- Get current branch name
function M.get_current_branch()
  local handle = io.popen("git branch --show-current 2>/dev/null")
  if not handle then
    return nil
  end
  
  local branch = handle:read("*a"):gsub("\n", "")
  handle:close()
  
  if vim.v.shell_error ~= 0 or branch == "" then
    return nil
  end
  
  return branch
end

-- Cache PR for current branch and repository
function M.cache_branch_pr_mapping(branch, pr_number)
  local repo_id = M.get_repository_identifier()
  if not repo_id then
    vim.notify("Could not determine repository for caching", vim.log.levels.WARN)
    return
  end
  
  local cache_data = M.load_branch_pr_cache()
  
  -- Ensure repository entry exists
  if not cache_data.repositories[repo_id] then
    cache_data.repositories[repo_id] = {
      branch_to_pr = {},
      last_updated = nil
    }
  end
  
  cache_data.repositories[repo_id].branch_to_pr[branch] = pr_number
  cache_data.repositories[repo_id].last_updated = os.date("!%Y-%m-%dT%H:%M:%SZ")
  
  M.save_branch_pr_cache(cache_data)
  vim.notify(string.format("💾 Cached PR #%d for branch '%s' in %s", pr_number, branch, repo_id), vim.log.levels.INFO)
end

-- Get current PR number for the branch
function M.get_current_pr()
  -- Return cached PR if available in memory
  if state.current_pr then
    return state.current_pr
  end
  
  if not M.config.auto_detect_pr then
    return nil
  end
  
  -- Get current branch name
  local current_branch = M.get_current_branch()
  if not current_branch then
    vim.notify("Could not determine current branch", vim.log.levels.ERROR)
    return nil
  end
  
  -- Get repository identifier
  local repo_id = M.get_repository_identifier()
  if not repo_id then
    vim.notify("Could not determine repository", vim.log.levels.ERROR)
    return nil
  end
  
  -- Check JSON cache first
  local cache_data = M.load_branch_pr_cache()
  if cache_data.repositories and 
     cache_data.repositories[repo_id] and 
     cache_data.repositories[repo_id].branch_to_pr and 
     cache_data.repositories[repo_id].branch_to_pr[current_branch] then
    local cached_pr = cache_data.repositories[repo_id].branch_to_pr[current_branch]
    state.current_pr = cached_pr
    vim.notify(string.format("📋 Found cached PR #%d for branch '%s' in %s", cached_pr, current_branch, repo_id), vim.log.levels.INFO)
    return cached_pr
  end
  
  -- No cache hit, query GitHub API
  vim.notify(string.format("🔍 Looking up PR for branch '%s' in %s...", current_branch, repo_id), vim.log.levels.INFO)
  
  local handle = io.popen(M.config.gh_path .. " pr status --json number 2>/dev/null")
  if not handle then
    vim.notify("Failed to execute gh command", vim.log.levels.ERROR)
    return nil
  end
  
  local result = handle:read("*a")
  handle:close()
  
  if result == "" then
    vim.notify("No open PR found for current branch", vim.log.levels.WARN)
    return nil
  end
  
  local success, data = pcall(vim.json.decode, result)
  if not success or not data then
    vim.notify("Failed to parse PR information", vim.log.levels.ERROR)
    return nil
  end
  
  -- Handle the actual JSON structure: { "createdBy": [], "currentBranch": { "number": 2 }, "needsReview": [] }
  local pr_number = nil
  
  -- Check currentBranch first (PR for current branch)
  if data.currentBranch and data.currentBranch.number then
    pr_number = data.currentBranch.number
  -- Check createdBy array (PRs created by current user)
  elseif data.createdBy and #data.createdBy > 0 then
    pr_number = data.createdBy[1].number
  -- Check needsReview array (PRs that need review from current user)
  elseif data.needsReview and #data.needsReview > 0 then
    pr_number = data.needsReview[1].number
  end
  
  if not pr_number then
    vim.notify("No active PR found for current branch", vim.log.levels.WARN)
    return nil
  end
  
  -- Cache the result both in memory and JSON file
  state.current_pr = pr_number
  M.cache_branch_pr_mapping(current_branch, pr_number)
  vim.notify(string.format("✓ Detected PR #%d for branch '%s' in %s", pr_number, current_branch, repo_id), vim.log.levels.INFO)
  return pr_number
end

-- Get the PR's head commit SHA (needed for inline comments)
function M.get_pr_head_commit_sha()
  local pr_number = M.get_current_pr()
  if not pr_number then
    return nil
  end
  
  local repo_info = M.get_repo_info()
  if not repo_info then
    return nil
  end
  
  -- Get PR details to find the head commit
  local api_cmd = string.format('%s api repos/%s/%s/pulls/%d',
    M.config.gh_path,
    repo_info.owner,
    repo_info.name,
    pr_number
  )
  
  local handle = io.popen(api_cmd .. " 2>/dev/null")
  if not handle then
    return nil
  end
  
  local result = handle:read("*a")
  handle:close()
  
  if result == "" then
    return nil
  end
  
  local success, pr_data = pcall(vim.json.decode, result)
  if not success or not pr_data or not pr_data.head or not pr_data.head.sha then
    return nil
  end
  
  return pr_data.head.sha
end

-- Get the latest commit SHA for the current branch (needed for inline comments)
function M.get_current_commit_sha()
  local handle = io.popen("git rev-parse HEAD 2>/dev/null")
  if not handle then
    return nil
  end
  
  local result = handle:read("*a"):gsub("\n", "")
  handle:close()
  
  if vim.v.shell_error ~= 0 or result == "" then
    return nil
  end
  
  return result
end

-- Get current file path and line number from diffview
function M.get_file_and_line()
  local current_file = vim.fn.expand("%:p")
  local line_number = vim.fn.line(".")
  
  -- Handle diffview:// URLs specially
  if current_file:match("^diffview://") then
    -- Check for special diffview buffers that aren't actual files
    if current_file:match("diffview:///panels/") or 
       current_file:match("diffview:///null") or
       current_file:match("DiffviewFilePanel") then
      -- These are special UI panels, not file diffs
      return nil
    end
    
    -- Extract the actual file path from diffview URL
    -- Pattern: diffview:///path/to/repo/.git/hash/actual/file/path
    local file_part = current_file:match("diffview:///.+/%.git/[^/]+/(.+)$")
    if file_part then
      return {
        file = file_part,
        line = line_number,
        absolute_path = current_file  -- Keep the original for buffer operations
      }
    else
      -- Unrecognized diffview pattern, silently return nil
      return nil
    end
  end
  
  -- Convert absolute path to relative path from git root for regular files
  local git_root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
  if vim.v.shell_error ~= 0 then
    vim.notify("Not in a git repository", vim.log.levels.ERROR)
    return nil
  end
  
  local relative_path = current_file:gsub("^" .. vim.pesc(git_root) .. "/", "")
  
  return {
    file = relative_path,
    line = line_number,
    absolute_path = current_file
  }
end

-- Prompt user for comment text using a floating window
function M.prompt_comment(file_info)
  -- Store the current window before opening comment buffer
  local original_win = vim.api.nvim_get_current_win()
  
  -- Get screen dimensions
  local width = vim.o.columns
  local height = math.min(12, math.floor(vim.o.lines * 0.3)) -- Max 12 lines or 30% of screen
  
  -- Create floating window at bottom of screen
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = vim.o.lines - height,
    col = 0,
    style = 'minimal',
    border = {'─', '─', '─', '', '', '', '─', ''},  -- Only top border
    title = " 💬 New PR Comment ",
    title_pos = "left",
  })
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  -- Set window options
  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'linebreak', true)
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'cursorline', true)
  
  -- Add helpful header
  local header_lines = {
    string.format("PR Comment for %s:%d", file_info.file, file_info.line),
    "Write your comment below. Ctrl+S to post, Ctrl+X to cancel, <leader>gf to refocus.",
    "",
    ""
  }
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header_lines)
  
  -- Store references globally for refocus functionality
  _G.pr_comment_window = win
  _G.pr_comment_buffer = buf
  
  -- Move cursor to the first line after header
  vim.api.nvim_win_set_cursor(win, {4, 0})
  
  -- Enter insert mode
  vim.cmd('startinsert')
  
  -- Create autocommand group
  local group = vim.api.nvim_create_augroup("PRCommentFloating", { clear = true })
  
  -- Function to post comment
  local function post_comment()
    -- Get the comment text (skip header lines)
    local lines = vim.api.nvim_buf_get_lines(buf, 3, -1, false)
    
    -- Remove empty lines from the end
    while #lines > 0 and lines[#lines]:match("^%s*$") do
      table.remove(lines)
    end
    
    local comment_text = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Clear global references
    _G.pr_comment_window = nil
    _G.pr_comment_buffer = nil
    
    -- Close the floating window
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    
    -- Return focus to original window
    if original_win and vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    
    -- Post the comment
    if comment_text ~= "" then
      M.post_comment_with_confirmation(comment_text, file_info)
    else
      vim.notify("Comment is empty - not posting", vim.log.levels.INFO)
    end
  end
  
  -- Function to cancel comment
  local function cancel_comment()
    -- Clear global references
    _G.pr_comment_window = nil
    _G.pr_comment_buffer = nil
    
    -- Close the floating window
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    
    -- Return focus to original window
    if original_win and vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    
    vim.notify("Comment cancelled", vim.log.levels.INFO)
  end
  
  -- Set up keymaps for the floating window
  local keymap_opts = { buffer = buf, noremap = true, silent = true }
  
  -- Ctrl+S to post comment
  vim.keymap.set({'n', 'i'}, '<C-s>', function()
    vim.cmd('stopinsert')
    post_comment()
  end, keymap_opts)
  
  -- Ctrl+X to cancel
  vim.keymap.set({'n', 'i'}, '<C-x>', function()
    vim.cmd('stopinsert')
    cancel_comment()
  end, keymap_opts)
  
  -- Escape to cancel (additional convenience)
  vim.keymap.set({'n', 'i'}, '<Esc>', function()
    vim.cmd('stopinsert')
    cancel_comment()
  end, keymap_opts)
  
  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd({"BufWipeout", "BufDelete"}, {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      _G.pr_comment_window = nil
      _G.pr_comment_buffer = nil
      
      if original_win and vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
      end
    end,
  })
  
  return true
end

-- Post comment with confirmation dialog
function M.post_comment_with_confirmation(comment_text, file_info, reply_to_comment_id)
  local pr_number = M.get_current_pr()
  if not pr_number then
    return
  end
  
  -- Post comment directly without confirmation (saving the buffer is confirmation enough)
  local success, message = M.post_comment(pr_number, comment_text, file_info, reply_to_comment_id)
  M.handle_errors(success, message, "post_comment")
  
  if success then
    -- Refresh comments to show the new one
    vim.defer_fn(function()
      M.refresh_comments()
    end, 1000)
  end
end

-- Get diff position for a line (different from line number - counts diff lines)
function M.get_diff_position_for_line(file_path, line_number)
  local pr_number = M.get_current_pr()
  if not pr_number then
    return nil
  end
  
  -- Get which side we're on
  local side = M.get_diff_side()
  
  -- Get the diff for this PR
  local diff_cmd = string.format('%s pr diff %d', M.config.gh_path, pr_number)
  local handle = io.popen(diff_cmd .. " 2>/dev/null")
  if not handle then
    return nil
  end
  
  local diff_output = handle:read("*a")
  handle:close()
  
  if diff_output == "" then
    return nil
  end
  
  -- Parse diff to find position
  local in_target_file = false
  local position = 0
  local current_old_line = 0  -- For LEFT side
  local current_new_line = 0  -- For RIGHT side
  
  for line in diff_output:gmatch("[^\r\n]+") do
    -- Skip file headers
    if line:match("^diff %-%-git") then
      position = 0
      in_target_file = false
    elseif line:match("^%+%+%+ b/" .. vim.pesc(file_path)) or line:match("^%+%+%+ a/" .. vim.pesc(file_path)) then
      in_target_file = true
    elseif line:match("^%+%+%+ ") then
      in_target_file = false
    elseif in_target_file then
      if line:match("^@@") then
        -- Parse hunk header
        local old_start, old_count, new_start, new_count = line:match("@@%s*%-(%d+),?(%d*)%s*%+(%d+),?(%d*)%s*@@")
        if old_start and new_start then
          current_old_line = tonumber(old_start) - 1   -- Start one before the first line
          current_new_line = tonumber(new_start) - 1   -- Start one before the first line
        end
        position = position + 1
      elseif line:match("^%+") then
        -- Added line (only exists on RIGHT side)
        current_new_line = current_new_line + 1
        position = position + 1
        if side == "RIGHT" and current_new_line == line_number then
          return position
        end
      elseif line:match("^%-") then
        -- Removed line (only exists on LEFT side)
        current_old_line = current_old_line + 1
        position = position + 1
        if side == "LEFT" and current_old_line == line_number then
          return position
        end
      elseif line:match("^%s") then
        -- Context line (exists on both sides)
        current_old_line = current_old_line + 1
        current_new_line = current_new_line + 1
        position = position + 1
        if (side == "LEFT" and current_old_line == line_number) or 
           (side == "RIGHT" and current_new_line == line_number) then
          return position
        end
      end
    end
  end
  
  return nil
end

-- Post comment to GitHub PR (Updated to use official API format)
function M.post_comment(pr_number, comment_text, file_info, reply_to_comment_id)
  if not pr_number or not comment_text or comment_text == "" then
    return false, "Missing required parameters"
  end
  
  local repo_info = M.get_repo_info()
  if not repo_info then
    return false, "Could not get repository information"
  end
  
  local commit_sha = M.get_pr_head_commit_sha()
  if not commit_sha then
    return false, "Could not get PR head commit SHA"
  end
  
  -- Use official GitHub API format (as per docs)
  local api_data = {
    body = comment_text,
    commit_id = commit_sha,
  }
  
  -- If this is a reply to an existing comment, use in_reply_to
  if reply_to_comment_id then
    api_data.in_reply_to = reply_to_comment_id
    vim.notify(string.format("🔗 Posting reply to comment ID: %s", reply_to_comment_id), vim.log.levels.INFO)
  else
    -- For new comments, we need position and path info
    local position = M.get_diff_position_for_line(file_info.file, file_info.line)
    if not position then
      return false, "Could not determine diff position for this line"
    end
    
    local diff_side = M.get_diff_side()
    api_data.path = file_info.file
    api_data.position = position - 1  -- Adjust for GitHub's 0-based position indexing
    api_data.side = diff_side
    vim.notify(string.format("📝 Posting new comment at %s:%d (%s)", file_info.file, file_info.line, diff_side), vim.log.levels.INFO)
  end
  
  -- Convert to JSON
  local json_data = vim.json.encode(api_data)
  
  -- Create temporary files for output and error capture
  local temp_output_file = vim.fn.tempname()
  local temp_error_file = vim.fn.tempname()
  
  -- Use gh api to post inline comment with full output capture
  local api_cmd = string.format(
    '%s api repos/%s/%s/pulls/%d/comments --method POST --input - >%s 2>%s',
    M.config.gh_path,
    repo_info.owner,
    repo_info.name,
    pr_number,
    temp_output_file,
    temp_error_file
  )
  
  -- Execute with JSON data as input
  local handle = io.popen(api_cmd, "w")
  if not handle then
    vim.fn.delete(temp_output_file)
    vim.fn.delete(temp_error_file)
    return false, "Failed to execute gh api command"
  end
  
  handle:write(json_data)
  handle:close()
  
  -- Check the exit status
  local exit_status = vim.v.shell_error
  
  -- Read the API response
  local api_response = ""
  if vim.fn.filereadable(temp_output_file) == 1 then
    local output_handle = io.open(temp_output_file, "r")
    if output_handle then
      api_response = output_handle:read("*a")
      output_handle:close()
    end
  end
  
  -- Read any error output
  local error_content = ""
  if vim.fn.filereadable(temp_error_file) == 1 then
    local error_handle = io.open(temp_error_file, "r")
    if error_handle then
      error_content = error_handle:read("*a")
      error_handle:close()
    end
  end
  
  -- Clean up temp files
  vim.fn.delete(temp_output_file)
  vim.fn.delete(temp_error_file)
  
  -- Check for API success by examining the response
  local api_success = false
  local error_message = "Unknown error"
  
  if api_response ~= "" then
    -- Try to parse the API response
    local success, response_data = pcall(vim.json.decode, api_response)
    if success and response_data then
      -- Check if response contains expected fields for a successful comment
      if response_data.id and response_data.body and response_data.user then
        api_success = true
      elseif response_data.message then
        -- Response contains an error message
        error_message = response_data.message
        if response_data.errors and #response_data.errors > 0 then
          local error_details = {}
          for _, err in ipairs(response_data.errors) do
            table.insert(error_details, err.message or tostring(err))
          end
          error_message = error_message .. ": " .. table.concat(error_details, ", ")
        end
      end
    else
      -- Failed to parse response as JSON, might be an error
      error_message = "Invalid API response: " .. api_response:sub(1, 200)
    end
  elseif error_content ~= "" then
    -- No output but there's error content
    local success, error_data = pcall(vim.json.decode, error_content)
    if success and error_data.message then
      error_message = error_data.message
      if error_data.errors and #error_data.errors > 0 then
        local error_details = {}
        for _, err in ipairs(error_data.errors) do
          table.insert(error_details, err.message or tostring(err))
        end
        error_message = error_message .. ": " .. table.concat(error_details, ", ")
      end
    else
      error_message = error_content:gsub("\n", " "):sub(1, 200)
    end
  elseif exit_status ~= 0 then
    error_message = string.format("Command failed with exit status %d", exit_status)
  else
    error_message = "No response from GitHub API"
  end
  
  if not api_success then
    return false, string.format("GitHub API error: %s", error_message)
  end
  
  return true, reply_to_comment_id and "Reply posted successfully" or "Comment posted successfully"
end

-- Handle errors and provide user feedback
function M.handle_errors(success, message, context)
  if success then
    vim.notify("✅ " .. (message or "PR comment posted successfully"), vim.log.levels.INFO)
  else
    vim.notify("❌ " .. (message or "Failed to post PR comment"), vim.log.levels.ERROR)
  end
end

-- Main function to add PR comment (Updated to use buffer)
function M.add_pr_comment()
  -- Check if gh CLI is available
  if vim.fn.executable(M.config.gh_path) == 0 then
    vim.notify("gh CLI not found. Please install GitHub CLI.", vim.log.levels.ERROR)
    return
  end
  
  -- Get current PR
  local pr_number = M.get_current_pr()
  if not pr_number then
    return
  end
  
  -- Get file and line information
  local file_info = M.get_file_and_line()
  if not file_info then
    return
  end
  
  -- Open comment buffer
  M.prompt_comment(file_info)
end

-- Phase 2: Comment Viewing Functions

-- Get repository owner and name
function M.get_repo_info()
  if state.repo_info then
    return state.repo_info
  end
  
  local handle = io.popen(M.config.gh_path .. " repo view --json owner,name 2>/dev/null")
  if not handle then
    return nil
  end
  
  local result = handle:read("*a")
  handle:close()
  
  if result == "" then
    return nil
  end
  
  local success, data = pcall(vim.json.decode, result)
  if not success or not data or not data.owner or not data.name then
    return nil
  end
  
  state.repo_info = {
    owner = data.owner.login,
    name = data.name
  }
  
  return state.repo_info
end

-- Download and cache profile picture
function M.download_profile_picture(username, avatar_url)
  local cache_path = M.config.cache_dir .. "/profile_pics/" .. username .. ".png"
  
  -- Check if already cached
  if vim.fn.filereadable(cache_path) == 1 then
    state.profile_pics_cache[username] = cache_path
    return cache_path
  end
  
  -- Ensure cache directory exists
  vim.fn.mkdir(M.config.cache_dir .. "/profile_pics", "p")
  
  -- Download using curl with better error handling
  local download_cmd = string.format('curl -s -L --max-time 10 --retry 2 "%s" -o "%s"', avatar_url, cache_path)
  local result = vim.fn.system(download_cmd)
  
  if vim.v.shell_error == 0 and vim.fn.filereadable(cache_path) == 1 then
    -- Verify it's actually an image file (basic check)
    local file_size = vim.fn.getfsize(cache_path)
    if file_size > 100 then  -- Basic sanity check
      state.profile_pics_cache[username] = cache_path
      return cache_path
    else
      -- Remove invalid file
      vim.fn.delete(cache_path)
    end
  end
  
  return nil
end

-- Create a left-side preview window (for auto-preview)
function M.create_left_preview_window(comments)
  -- Use a fixed width of 80 characters for better comment readability
  local panel_width = 80
  
  -- Store the current window before creating the preview buffer
  local original_win = vim.api.nvim_get_current_win()
  
  -- Create a left-side vertical split
  vim.cmd('topleft ' .. panel_width .. 'vsplit')
  
  -- Create buffer for the preview window
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_get_current_win()
  
  -- Set the buffer in the new window
  vim.api.nvim_win_set_buf(win, buf)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_name(buf, 'PR Comments Preview')
  
  -- Set window-local options
  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'linebreak', true)
  vim.api.nvim_win_set_option(win, 'cursorline', true)
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'rightleft', false)
  vim.api.nvim_win_set_option(win, 'sidescroll', 0)
  vim.api.nvim_win_set_option(win, 'winfixwidth', true)  -- Prevent auto-resizing by diffview's wincmd =
  
  return buf, win, original_win
end

-- Create a regular buffer window for displaying PR comments (better for images)
function M.create_comment_buffer_window(comments)
  -- Use a fixed width of 80 characters for better comment readability (same as auto-preview)
  local width = 80
  
  -- Store the original window before creating the comment buffer
  local original_win = vim.api.nvim_get_current_win()
  
  -- Create a vertical split on the right side
  vim.cmd('botright ' .. width .. 'vsplit')
  
  -- Create buffer for the comment window
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_get_current_win()
  
  -- Set the buffer in the new window
  vim.api.nvim_win_set_buf(win, buf)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_name(buf, 'PR Comments')
  
  -- Set window-local options
  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'linebreak', true)
  vim.api.nvim_win_set_option(win, 'cursorline', true)
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'rightleft', false)  -- Ensure left-to-right text
  vim.api.nvim_win_set_option(win, 'sidescroll', 0)     -- Allow horizontal scrolling
  vim.api.nvim_win_set_option(win, 'winfixwidth', true)  -- Prevent auto-resizing by diffview's wincmd =
  
  return buf, win, original_win
end

-- Download profile pictures for comments
function M.download_comment_profile_pictures(comments)
  if not M.config.show_profile_pics then
    return
  end
  
  for _, comment in ipairs(comments) do
    if comment.avatar_url and comment.username then
      -- Download in background, don't block
      vim.defer_fn(function()
        M.download_profile_picture(comment.username, comment.avatar_url)
      end, 0)
    end
  end
end

-- Display profile picture placeholder for future implementation
function M.display_profile_picture(buf, comment, line_start)
  -- Profile picture display will be implemented here later
  return
end

-- View PR comments for current line (Phase 2: Rich display with profile pictures)
function M.view_pr_comments()
  local file_info = M.get_file_and_line()
  if not file_info then
    vim.notify("Could not determine file and line information", vim.log.levels.WARN)
    return
  end
  
  local comments = state.comments_cache[file_info.file]
  if not comments then
    vim.notify("No cached comments for this file. Use <leader>gR to refresh all comments.", vim.log.levels.INFO)
    return
  end
  
  -- Filter comments for current line and side
  local current_side = M.get_diff_side()
  local line_comments = {}
  for _, comment in ipairs(comments) do
    if comment.line == file_info.line and comment.side == current_side then
      table.insert(line_comments, comment)
    end
  end
  
  if #line_comments == 0 then
    vim.notify(string.format("No comments found for line %d on %s side", file_info.line, current_side), vim.log.levels.INFO)
    return
  end
  
  -- Build thread structure from comments
  local threads = M.build_comment_threads(line_comments)
  
  if #threads == 0 then
    vim.notify("No comment threads found", vim.log.levels.INFO)
    return
  end
  
  -- Save auto-preview state and turn it off if needed
  local auto_was_enabled = M.config.auto_preview.enable
  state.auto_preview.saved_auto_state = auto_was_enabled
  
  local function open_explicit_view()
    -- Save current layout for restoration later
    M.save_explicit_layout()
    
    -- Download profile pictures in background
    M.download_comment_profile_pictures(line_comments)
    
    -- Create floating window
    local buf, win, original_win = M.create_comment_buffer_window(line_comments)
    
    -- Setup explicit comment view layout (close file panel, resize windows)
    M.setup_explicit_layout()
    
    -- Format and display threaded comments
    local all_lines = {}
    
    -- Add header
    table.insert(all_lines, string.format("╭─ 💬 Comments for %s:%d", file_info.file, file_info.line))
    if #threads > 1 then
      table.insert(all_lines, string.format("├─ 🧵 %d threads with %d total comments", #threads, #line_comments))
    else
      table.insert(all_lines, string.format("├─ 🧵 1 thread with %d comment(s)", #line_comments))
    end
    table.insert(all_lines, "╰─────────────────────────────────────────────────")
    table.insert(all_lines, "")
    
    local header_line_count = #all_lines
    
    -- Format threaded comments
    local thread_lines, highlight_info = M.format_threaded_comment_content(threads)
    for _, line in ipairs(thread_lines) do
      table.insert(all_lines, line)
    end
    
    -- Set buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
    
    -- Apply syntax highlighting
    for _, highlight_data in ipairs(highlight_info) do
      local line_num = header_line_count + highlight_data.line_offset
      for _, hl in ipairs(highlight_data.highlights) do
        if hl.start_col <= hl.end_col then
          vim.api.nvim_buf_add_highlight(buf, -1, hl.group, line_num, hl.start_col, hl.end_col + 1)
        end
      end
    end
    
    -- Apply header highlighting
    vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentHeader", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentMeta", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentBorder", 2, 0, -1)
    
    -- Make buffer read-only
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'readonly', true)
    
    -- Set up keymaps for the comment window
    local function close_window()
      -- Clean up any displayed images first
      M.cleanup_displayed_images()
      
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      
      -- Restore layout when explicitly closing comment view
      M.restore_explicit_layout()
      
      -- Return focus to original window if it's still valid
      if original_win and vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
      end
    end
    
    -- Store threads for reply functionality
    local current_threads = threads
    
    -- Close window on q, Esc, or clicking outside
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
      callback = close_window,
      noremap = true,
      silent = true,
      desc = 'Close PR comments window'
    })
    
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
      callback = close_window,
      noremap = true,
      silent = true,
      desc = 'Close PR comments window'
    })
    
    -- Add 'o' to open the GitHub conversation in browser
    vim.api.nvim_buf_set_keymap(buf, 'n', 'o', '', {
      callback = function()
        if #current_threads > 0 and current_threads[1].root.url then
          local comment_url = current_threads[1].root.url
          -- Use vim.ui.open if available (Neovim 0.10+), otherwise fallback to system open
          if vim.ui.open then
            vim.ui.open(comment_url)
          else
            local open_cmd = vim.fn.has('mac') == 1 and 'open' or (vim.fn.has('unix') == 1 and 'xdg-open' or 'start')
            vim.fn.system(string.format('%s "%s"', open_cmd, comment_url))
          end
          vim.notify(string.format("🔗 Opening comment discussion in browser"), vim.log.levels.INFO)
        else
          -- Fallback to general PR URL
          local pr_number = M.get_current_pr()
          local repo_info = M.get_repo_info()
          if pr_number and repo_info then
            local github_url = string.format("https://github.com/%s/%s/pull/%d", repo_info.owner, repo_info.name, pr_number)
            if vim.ui.open then
              vim.ui.open(github_url)
            else
              local open_cmd = vim.fn.has('mac') == 1 and 'open' or (vim.fn.has('unix') == 1 and 'xdg-open' or 'start')
              vim.fn.system(string.format('%s "%s"', open_cmd, github_url))
            end
            vim.notify(string.format("🔗 Opening PR #%d in browser", pr_number), vim.log.levels.INFO)
          else
            vim.notify("❌ Could not determine comment or PR URL", vim.log.levels.ERROR)
          end
        end
      end,
      noremap = true,
      silent = true,
      desc = 'Open GitHub comment discussion in browser'
    })
    
    -- Auto-close when focus is lost
    vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
      buffer = buf,
      callback = close_window,
      once = true
    })
    
    local thread_summary = #threads == 1 and "1 thread" or string.format("%d threads", #threads)
    vim.notify(string.format("📖 Showing %s with %d comment(s) for line %d (%s side)", 
      thread_summary, #line_comments, file_info.line, current_side), vim.log.levels.INFO)
  end
  
  -- If auto-preview is enabled, turn it off and add delay before opening explicit view
  if auto_was_enabled then
    vim.notify("🔄 Disabling auto-preview for explicit view...", vim.log.levels.INFO)
    M.config.auto_preview.enable = false
    M.close_auto_preview() -- Close any existing auto-preview
    
    -- Add delay to allow transition time
    vim.defer_fn(open_explicit_view, 200)
  else
    -- Auto-preview was already off, open immediately
    open_explicit_view()
  end
end

-- View all PR comments for current file (Phase 2 enhancement)
function M.view_all_file_comments()
  local file_info = M.get_file_and_line()
  if not file_info then
    vim.notify("Could not determine file information", vim.log.levels.WARN)
    return
  end
  
  local comments = state.comments_cache[file_info.file]
  if not comments then
    vim.notify("No cached comments for this file. Use <leader>gR to refresh all comments.", vim.log.levels.INFO)
    return
  end
  
  if #comments == 0 then
    vim.notify("No comments found for this file", vim.log.levels.INFO)
    return
  end
  
  -- Group comments by line and side, then build threads for each group
  local comments_by_line_side = {}
  for _, comment in ipairs(comments) do
    local key = string.format("%d_%s", comment.line, comment.side)
    if not comments_by_line_side[key] then
      comments_by_line_side[key] = {
        line = comment.line,
        side = comment.side,
        comments = {}
      }
    end
    table.insert(comments_by_line_side[key].comments, comment)
  end
  
  -- Sort line groups by line number and side
  local sorted_line_groups = {}
  for _, group in pairs(comments_by_line_side) do
    table.insert(sorted_line_groups, group)
  end
  
  table.sort(sorted_line_groups, function(a, b)
    if a.line == b.line then
      return a.side < b.side  -- LEFT before RIGHT
    end
    return a.line < b.line
  end)
  
  -- Save auto-preview state and turn it off if needed
  local auto_was_enabled = M.config.auto_preview.enable
  state.auto_preview.saved_auto_state = auto_was_enabled
  
  local function open_explicit_view()
    -- Download profile pictures in background
    M.download_comment_profile_pictures(comments)
    
    -- Create floating window
    local buf, win, original_win = M.create_comment_buffer_window(comments)
    
    -- Format and display all comments with threading
    local all_lines = {}
    
    -- Add file header
    table.insert(all_lines, string.format("╭─ 📁 PR Comments for %s", file_info.file))
    table.insert(all_lines, string.format("├─ 📊 Total: %d comments across %d line(s)", #comments, #sorted_line_groups))
    table.insert(all_lines, "╰─────────────────────────────────────────────────")
    table.insert(all_lines, "")
    
    local header_line_count = #all_lines
    local all_highlight_info = {}
    
    for group_index, group in ipairs(sorted_line_groups) do
      -- Add line separator (except for first group)
      if group_index > 1 then
        table.insert(all_lines, "")
        local separator_line = "┌─────────────────────────────────────────────────┐"
        table.insert(all_lines, separator_line)
        table.insert(all_highlight_info, {
          line_offset = #all_lines - header_line_count - 1,
          highlights = {
            { group = "PRCommentBorder", start_col = 0, end_col = #separator_line - 1 }
          }
        })
        table.insert(all_lines, "")
      end
      
      -- Add line number header for each group
      local line_header = string.format("📍 Line %d", group.line)
      table.insert(all_lines, line_header)
      table.insert(all_highlight_info, {
        line_offset = #all_lines - header_line_count - 1,
        highlights = {
          { group = "PRCommentHeader", start_col = 0, end_col = #line_header - 1 }
        }
      })
      
      -- Build thread structure for this line
      local line_threads = M.build_comment_threads(group.comments)
      
      local thread_info_line
      if #line_threads > 1 then
        thread_info_line = string.format("   🧵 %d threads with %d comments", #line_threads, #group.comments)
      else
        thread_info_line = string.format("   🧵 1 thread with %d comment(s)", #group.comments)
      end
      table.insert(all_lines, thread_info_line)
      table.insert(all_highlight_info, {
        line_offset = #all_lines - header_line_count - 1,
        highlights = {
          { group = "PRCommentMeta", start_col = 0, end_col = #thread_info_line - 1 }
        }
      })
      table.insert(all_lines, "")
      
      -- Format threaded comments for this line
      local thread_lines, thread_highlights = M.format_threaded_comment_content(line_threads)
      local base_line_offset = #all_lines - header_line_count
      for _, line in ipairs(thread_lines) do
        table.insert(all_lines, line)
      end
      -- Adjust and add thread highlights
      for _, highlight_data in ipairs(thread_highlights) do
        table.insert(all_highlight_info, {
          line_offset = base_line_offset + highlight_data.line_offset,
          highlights = highlight_data.highlights
        })
      end
    end
    
    -- Set buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
    
    -- Apply syntax highlighting
    for _, highlight_data in ipairs(all_highlight_info) do
      local line_num = header_line_count + highlight_data.line_offset
      for _, hl in ipairs(highlight_data.highlights) do
        if hl.start_col <= hl.end_col and line_num >= 0 and line_num < #all_lines then
          vim.api.nvim_buf_add_highlight(buf, -1, hl.group, line_num, hl.start_col, hl.end_col + 1)
        end
      end
    end
    
    -- Apply header highlighting
    vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentHeader", 0, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentMeta", 1, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentBorder", 2, 0, -1)
    
    -- Make buffer read-only
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'readonly', true)
    
    -- Set up keymaps for the comment window
    local function close_window()
      -- Clean up any displayed images first
      M.cleanup_displayed_images()
      
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      
      -- Restore layout when explicitly closing comment view
      M.restore_explicit_layout()
      
      -- Return focus to original window if it's still valid
      if original_win and vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
      end
    end
    
    -- Close window on q, Esc
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
      callback = close_window,
      noremap = true,
      silent = true,
      desc = 'Close PR comments window'
    })
    
    vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
      callback = close_window,
      noremap = true,
      silent = true,
      desc = 'Close PR comments window'
    })
    
    -- Add 'o' to open the GitHub conversation in browser
    vim.api.nvim_buf_set_keymap(buf, 'n', 'o', '', {
      callback = function()
        if #current_threads > 0 and current_threads[1].root.url then
          local comment_url = current_threads[1].root.url
          -- Use vim.ui.open if available (Neovim 0.10+), otherwise fallback to system open
          if vim.ui.open then
            vim.ui.open(comment_url)
          else
            local open_cmd = vim.fn.has('mac') == 1 and 'open' or (vim.fn.has('unix') == 1 and 'xdg-open' or 'start')
            vim.fn.system(string.format('%s "%s"', open_cmd, comment_url))
          end
          vim.notify(string.format("🔗 Opening comment discussion in browser"), vim.log.levels.INFO)
        else
          -- Fallback to general PR URL
          local pr_number = M.get_current_pr()
          local repo_info = M.get_repo_info()
          if pr_number and repo_info then
            local github_url = string.format("https://github.com/%s/%s/pull/%d", repo_info.owner, repo_info.name, pr_number)
            if vim.ui.open then
              vim.ui.open(github_url)
            else
              local open_cmd = vim.fn.has('mac') == 1 and 'open' or (vim.fn.has('unix') == 1 and 'xdg-open' or 'start')
              vim.fn.system(string.format('%s "%s"', open_cmd, github_url))
            end
            vim.notify(string.format("🔗 Opening PR #%d in browser", pr_number), vim.log.levels.INFO)
          else
            vim.notify("❌ Could not determine comment or PR URL", vim.log.levels.ERROR)
          end
        end
      end,
      noremap = true,
      silent = true,
      desc = 'Open GitHub comment discussion in browser'
    })
    
    -- Auto-close when focus is lost
    vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
      buffer = buf,
      callback = close_window,
      once = true
    })
    
    local total_threads = 0
    for _, group in ipairs(sorted_line_groups) do
      local line_threads = M.build_comment_threads(group.comments)
      total_threads = total_threads + #line_threads
    end
    
    vim.notify(string.format("📖 Showing %d threads with %d comment(s) across %d line(s) for %s", 
      total_threads, #comments, #sorted_line_groups, file_info.file), vim.log.levels.INFO)
  end
  
  -- If auto-preview is enabled, turn it off and add delay before opening explicit view
  if auto_was_enabled then
    vim.notify("🔄 Disabling auto-preview for explicit view...", vim.log.levels.INFO)
    M.config.auto_preview.enable = false
    M.close_auto_preview() -- Close any existing auto-preview
    
    -- Add delay to allow transition time
    vim.defer_fn(open_explicit_view, 200)
  else
    -- Auto-preview was already off, open immediately
    open_explicit_view()
  end
end

-- Refresh comments and update sign column
function M.refresh_comments()
  -- Just refresh all comments - simpler and more reliable than per-file
  M.refresh_all_comments()
end

-- Setup autocmds for automatic comment loading in diffview
function M.setup_diffview_autocmds()
  local group = vim.api.nvim_create_augroup("PRComments", { clear = true })
  
  -- Simple autocmd to update signs when entering buffers with cached comments
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function()
      -- Only run if we have cached PR data and this buffer has comments
      if state.current_pr and vim.tbl_count(state.comments_cache) > 0 then
        vim.defer_fn(function()
          M.update_signs_for_current_buffer()
        end, 100)
      end
    end,
  })
  
  -- Auto-preview on cursor movement
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
    group = group,
    pattern = "*",
    callback = function()
      -- Only run if we have cached PR data and auto-preview is enabled
      if state.current_pr and vim.tbl_count(state.comments_cache) > 0 then
        M.handle_cursor_moved()
      end
    end,
  })
  
  -- Close auto-preview when leaving buffer
  vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
    group = group,
    pattern = "*",
    callback = function()
      if M.config.auto_preview.enable then
        M.close_auto_preview()
      end
    end,
  })
end

-- Setup function
function M.setup(user_config)
  -- Merge user config with defaults
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end
  
  -- Create cache directory
  vim.fn.mkdir(M.config.cache_dir, "p")
  vim.fn.mkdir(M.config.cache_dir .. "/profile_pics", "p")
  
  -- Setup signs for comment indicators
  if M.config.sign_column.enable then
    vim.fn.sign_define(M.config.sign_column.sign_name, {
      text = M.config.sign_column.text,
      texthl = M.config.sign_column.texthl,
      numhl = M.config.sign_column.numhl,
    })
  end
  
  -- Setup highlight groups for colored comments (gruvbox-based palette)
  vim.api.nvim_set_hl(0, "PRCommentHeader", { fg = "#fe8019", bold = true })         -- Gruvbox bright orange headers
  vim.api.nvim_set_hl(0, "PRCommentUsername", { fg = "#d3869b", bold = true })       -- Gruvbox purple usernames  
  vim.api.nvim_set_hl(0, "PRCommentMeta", { fg = "#928374" })                        -- Gruvbox gray metadata
  vim.api.nvim_set_hl(0, "PRCommentBorder", { fg = "#665c54" })                      -- Gruvbox dark gray borders
  vim.api.nvim_set_hl(0, "PRCommentContent", { fg = "#ebdbb2" })                     -- Gruvbox light content
  vim.api.nvim_set_hl(0, "PRCommentReply", { fg = "#8ec07c" })                       -- Gruvbox aqua reply indicators
  vim.api.nvim_set_hl(0, "PRCommentThread", { fg = "#fabd2f", bold = true })         -- Gruvbox yellow thread separators
  vim.api.nvim_set_hl(0, "PRCommentCount", { fg = "#83a598", bold = true, italic = true })  -- Gruvbox blue for comment counts
  
  -- Setup autocmds for diffview integration
  M.setup_diffview_autocmds()
  
  -- Setup key mappings for comment navigation
  vim.keymap.set('n', ']d', function() M.goto_next_comment() end, { 
    desc = 'Go to next PR comment line',
    silent = true 
  })
  vim.keymap.set('n', '[d', function() M.goto_prev_comment() end, { 
    desc = 'Go to previous PR comment line',
    silent = true 
  })
  
  -- Setup key mapping for auto-preview toggle
  vim.keymap.set('n', '<leader>ga', function() M.toggle_auto_preview() end, {
    desc = 'Toggle PR comment auto-preview',
    silent = true
  })
  
  -- Setup key mapping for explicit comment viewing
  vim.keymap.set('n', '<leader>gv', function() M.view_pr_comments() end, {
    desc = 'View PR comments for current line',
    silent = true
  })

  -- Setup key mapping for PR file comment summary
  vim.keymap.set('n', '<leader>gl', function() M.view_pr_file_summary() end, {
    desc = 'View PR file comment summary',
    silent = true
  })
end

-- Clear cached PR (useful for testing or switching branches)
function M.clear_pr_cache()
  state.current_pr = nil
  state.repo_info = nil
  state.comments_cache = {}
  
  -- Clean up auto-preview
  M.close_auto_preview()
  
  -- Also clear the JSON cache file
  local cache_file = M.get_branch_pr_cache_path()
  if vim.fn.filereadable(cache_file) == 1 then
    vim.fn.delete(cache_file)
    vim.notify("🗑️  PR cache cleared (both memory and JSON file)", vim.log.levels.INFO)
  else
    vim.notify("🗑️  PR cache cleared (memory only)", vim.log.levels.INFO)
  end
end

-- Clear profile picture cache
function M.clear_profile_pic_cache()
  local profile_cache_dir = M.config.cache_dir .. "/profile_pics"
  
  -- Clear memory cache
  state.profile_pics_cache = {}
  
  -- Clear disk cache
  local files_deleted = 0
  if vim.fn.isdirectory(profile_cache_dir) == 1 then
    local files = vim.fn.glob(profile_cache_dir .. "/*.png", false, true)
    for _, file in ipairs(files) do
      if vim.fn.delete(file) == 0 then
        files_deleted = files_deleted + 1
      end
    end
  end
  
  vim.notify(string.format("🖼️  Cleared %d profile picture(s) from cache", files_deleted), vim.log.levels.INFO)
end

-- Clear all caches (PR data and profile pictures)
function M.clear_all_caches()
  M.clear_pr_cache()
  M.clear_profile_pic_cache()
  M.cleanup_displayed_images()
  vim.notify("🧹 All caches cleared", vim.log.levels.INFO)
end

-- Debug function to show branch-PR cache status
function M.debug_branch_pr_cache()
  local current_branch = M.get_current_branch()
  local repo_id = M.get_repository_identifier()
  local cache_data = M.load_branch_pr_cache()
  
  vim.notify("=== DEBUG: Branch-PR Cache Status ===", vim.log.levels.INFO)
  vim.notify(string.format("Current repository: %s", repo_id or "unknown"), vim.log.levels.INFO)
  vim.notify(string.format("Current branch: %s", current_branch or "unknown"), vim.log.levels.INFO)
  vim.notify(string.format("Memory cache PR: %s", state.current_pr or "none"), vim.log.levels.INFO)
  
  if cache_data.repositories and vim.tbl_count(cache_data.repositories) > 0 then
    vim.notify("JSON cache contents:", vim.log.levels.INFO)
    for repo, repo_data in pairs(cache_data.repositories) do
      local current_repo_indicator = (repo == repo_id) and " ← current repo" or ""
      vim.notify(string.format("  Repository: %s%s", repo, current_repo_indicator), vim.log.levels.INFO)
      
      if repo_data.branch_to_pr and vim.tbl_count(repo_data.branch_to_pr) > 0 then
        for branch, pr in pairs(repo_data.branch_to_pr) do
          local current_branch_indicator = (repo == repo_id and branch == current_branch) and " ← current branch" or ""
          vim.notify(string.format("    %s → PR #%d%s", branch, pr, current_branch_indicator), vim.log.levels.INFO)
        end
      else
        vim.notify("    (no branches cached)", vim.log.levels.INFO)
      end
      
      if repo_data.last_updated then
        vim.notify(string.format("    Last updated: %s", repo_data.last_updated), vim.log.levels.INFO)
      end
    end
  else
    vim.notify("JSON cache: empty", vim.log.levels.INFO)
  end
  vim.notify("=== END DEBUG ===", vim.log.levels.INFO)
end

-- Get all files changed in the current PR
function M.get_pr_files()
  local pr_number = M.get_current_pr()
  if not pr_number then
    return {}
  end
  
  local repo_info = M.get_repo_info()
  if not repo_info then
    vim.notify("Could not get repository information", vim.log.levels.ERROR)
    return {}
  end
  
  -- Get files from the PR using GitHub API
  local api_cmd = string.format('%s api repos/%s/%s/pulls/%d/files',
    M.config.gh_path,
    repo_info.owner,
    repo_info.name,
    pr_number
  )
  
  local handle = io.popen(api_cmd .. " 2>/dev/null")
  if not handle then
    vim.notify("Failed to fetch PR files", vim.log.levels.ERROR)
    return {}
  end
  
  local result = handle:read("*a")
  handle:close()
  
  if result == "" then
    return {}
  end
  
  local success, files = pcall(vim.json.decode, result)
  if not success or not files then
    vim.notify("Failed to parse PR files", vim.log.levels.ERROR)
    return {}
  end
  
  -- Extract just the filenames
  local file_list = {}
  for _, file in ipairs(files) do
    if file.filename and file.status ~= "removed" then
      table.insert(file_list, file.filename)
    end
  end
  
  return file_list
end

-- Load PR comments for all files in the current PR
function M.load_all_pr_comments()
  local pr_number = M.get_current_pr()
  if not pr_number then
    vim.notify("❌ No active PR found", vim.log.levels.WARN)
    return
  end
  
  -- Show progress for fetching PR files
  vim.notify("📁 Fetching PR files...", vim.log.levels.INFO)
  
  local pr_files = M.get_pr_files()
  if #pr_files == 0 then
    vim.notify("❌ No files found in PR", vim.log.levels.WARN)
    return
  end
  
  -- Show progress for fetching comments
  vim.notify(string.format("💬 Fetching comments for %d file(s)...", #pr_files), vim.log.levels.INFO)
  
  -- Get all PR comments at once (more efficient than per-file)
  local repo_info = M.get_repo_info()
  if not repo_info then
    vim.notify("❌ Could not get repository information", vim.log.levels.ERROR)
    return
  end
  
  
  -- Fetch all inline review comments using GitHub API
  local api_cmd = string.format('%s api repos/%s/%s/pulls/%d/comments',
    M.config.gh_path,
    repo_info.owner,
    repo_info.name,
    pr_number
  )
  
  local handle = io.popen(api_cmd .. " 2>/dev/null")
  if not handle then
    vim.notify("❌ Failed to fetch PR comments", vim.log.levels.ERROR)
    return
  end
  
  local result = handle:read("*a")
  handle:close()
  
  if result == "" then
    vim.notify(string.format("✅ No comments found in PR #%d", pr_number), vim.log.levels.INFO)
    return
  end
  
  local success, all_comments = pcall(vim.json.decode, result)
  if not success or not all_comments then
    vim.notify("❌ Failed to parse PR comments", vim.log.levels.ERROR)
    return
  end
  
  -- Show progress for processing comments
  vim.notify(string.format("⚙️  Processing %d comment(s)...", #all_comments), vim.log.levels.INFO)
  
  -- Group comments by file and include both LEFT and RIGHT sides
  local comments_by_file = {}
  local total_comments = 0
  
  for _, comment in ipairs(all_comments) do
    if comment.path and comment.line then
      -- Only include files that are in the PR and not removed
      local file_in_pr = false
      for _, pr_file in ipairs(pr_files) do
        if pr_file == comment.path then
          file_in_pr = true
          break
        end
      end
      
      -- Skip comments with nil/null line numbers (general PR comments, not inline)
      if file_in_pr and comment.line ~= vim.NIL and type(comment.line) ~= "userdata" then
        if not comments_by_file[comment.path] then
          comments_by_file[comment.path] = {}
        end
        
        
        table.insert(comments_by_file[comment.path], {
          id = comment.id,  -- Store comment ID for replies
          line = tonumber(comment.line) or comment.line,  -- Ensure line is a number if possible
          side = comment.side or "RIGHT",  -- Default to RIGHT if not specified
          username = comment.user.login,
          avatar_url = comment.user.avatar_url,
          body = comment.body,
          created_at = comment.created_at,
          url = comment.html_url,
          in_reply_to_id = comment.in_reply_to_id,  -- Thread information (corrected field name)
          original_line = comment.original_line,  -- For tracking original line in case of diff changes
          original_commit_id = comment.original_commit_id  -- For tracking commit context
        })
        
        total_comments = total_comments + 1
      end
    end
  end
  
  -- Cache comments for all files
  state.comments_cache = comments_by_file
  
  local file_count = vim.tbl_count(comments_by_file)
  if total_comments > 0 then
    vim.notify(string.format("✅ Loaded %d comment(s) across %d file(s) for PR #%d", 
      total_comments, file_count, pr_number), vim.log.levels.INFO)
  else
    vim.notify(string.format("✅ No comments found in PR #%d", pr_number), vim.log.levels.INFO)
  end
end

-- Auto-load PR comments when diffview opens (called from git.lua)
function M.auto_load_pr_comments()
  -- Show loading indicator
  vim.notify("🔄 Loading PR comments...", vim.log.levels.INFO)
  
  -- Small delay to ensure diffview is fully loaded
  vim.defer_fn(function()
    M.load_all_pr_comments()
    
    -- After loading comments, update signs for any currently loaded buffers
    if vim.tbl_count(state.comments_cache) > 0 then
      vim.defer_fn(function()
        M.update_all_diffview_signs()
      end, 500) -- Small delay after comment loading to update signs
    end
  end, 500)
end

-- Update signs for all currently loaded buffers (both diffview and regular)
function M.update_all_diffview_signs()
  if not M.config.sign_column.enable then
    return
  end
  
  local buffers_found = 0
  local signs_placed = 0
  
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      local file_path = nil
      local current_side = "RIGHT"  -- Default for regular files
      
      -- Handle diffview buffers
      if buf_name:match("^diffview://") and not buf_name:match("panels") and not buf_name:match("null") then
        file_path = buf_name:match("diffview:///.+/%.git/[^/]+/(.+)$")
        current_side = buf_name:match("^diffview:///") and "LEFT" or "RIGHT"
      -- Handle regular file buffers
      elseif buf_name ~= "" and not buf_name:match("^diffview://") then
        -- Convert absolute path to relative path from git root
        local git_root = vim.fn.system("git rev-parse --show-toplevel"):gsub("\n", "")
        if vim.v.shell_error == 0 and buf_name:match("^" .. vim.pesc(git_root)) then
          file_path = buf_name:gsub("^" .. vim.pesc(git_root) .. "/", "")
          current_side = "RIGHT"  -- Regular files show new content
        end
      end
      
      -- If we found a valid file path and have comments for it
      if file_path and state.comments_cache[file_path] then
        buffers_found = buffers_found + 1
        local comments = state.comments_cache[file_path]
        
        -- Clear existing signs
        vim.fn.sign_unplace("PRComments", { buffer = bufnr })
        
        -- Group comments by line and side, then count them
        local comments_by_line = {}
        for _, comment in ipairs(comments) do
          if comment.side == current_side then
            local key = comment.line
            if not comments_by_line[key] then
              comments_by_line[key] = 0
            end
            comments_by_line[key] = comments_by_line[key] + 1
          end
        end
        
        -- Place signs with comment counts
        for line_num, comment_count in pairs(comments_by_line) do
          -- Use number + single ASCII character (2 chars max for sign text)
          local sign_text = comment_count > 9 and "+" or (tostring(comment_count) .. "*")
          local sign_name = comment_count > 9 and "PRC_plus" or string.format("PRC_%d", comment_count)
          
          -- Define the sign if it doesn't exist
          if vim.fn.sign_getdefined(sign_name)[1] == nil then
            vim.fn.sign_define(sign_name, {
              text = sign_text,
              texthl = "PRCommentCount",  -- Custom highlight group for comment counts
            })
          end
          
          -- Validate parameters before placing sign
          if not bufnr or bufnr <= 0 then
            vim.notify("Invalid buffer number: " .. tostring(bufnr), vim.log.levels.ERROR)
            goto continue
          end
          
          if not line_num or line_num <= 0 then
            vim.notify("Invalid line number: " .. tostring(line_num), vim.log.levels.ERROR)
            goto continue
          end
          
          -- Check if buffer is valid
          if not vim.api.nvim_buf_is_valid(bufnr) then
            vim.notify("Buffer is not valid: " .. tostring(bufnr), vim.log.levels.ERROR)
            goto continue
          end
          
          -- Check if line exists in buffer
          local line_count = vim.api.nvim_buf_line_count(bufnr)
          if line_num > line_count then
            vim.notify("Line number " .. line_num .. " exceeds buffer line count " .. line_count, vim.log.levels.ERROR)
            goto continue
          end
          
          -- Place the sign
          local success, err = pcall(vim.fn.sign_place, 0, "PRComments", sign_name, bufnr, {
            lnum = line_num,
            priority = 10
          })
          
          if not success then
            vim.notify("Failed to place sign: " .. tostring(err) .. " (sign_name=" .. sign_name .. ", bufnr=" .. bufnr .. ", line=" .. line_num .. ")", vim.log.levels.ERROR)
          else
            signs_placed = signs_placed + 1
          end
          
          ::continue::
        end
        
        if signs_placed > 0 then
          -- Don't spam individual file messages during startup
          -- vim.notify(string.format("📍 Placed %d sign(s) on %s side for %s", 
          --   signs_placed, current_side, file_path), vim.log.levels.INFO)
        end
      end
    end
  end
end

-- Refresh all PR comments (clears entire cache and reloads)
function M.refresh_all_comments()
  -- Clear entire cache including displayed images
  state.comments_cache = {}
  M.cleanup_displayed_images()
  
  -- Reload all comments
  M.load_all_pr_comments()
end

-- Debug function to show all buffers and their names
function M.debug_buffers()
  vim.notify("=== DEBUG: All loaded buffers ===", vim.log.levels.INFO)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      local buf_type = vim.api.nvim_buf_get_option(bufnr, 'buftype')
      vim.notify(string.format("Buf %d: %s (type: %s)", bufnr, buf_name, buf_type), vim.log.levels.INFO)
    end
  end
  vim.notify("=== END DEBUG ===", vim.log.levels.INFO)
end

-- Update signs when entering buffers with cached comments  
function M.update_signs_for_current_buffer()
  local file_info = M.get_file_and_line()
  if not file_info then
    return
  end
  
  if not state.comments_cache[file_info.file] then
    return
  end
  
  local buf_nr = vim.fn.bufnr("%")
  local comments = state.comments_cache[file_info.file]
  local current_side = M.get_diff_side()
  
  if M.config.sign_column.enable and #comments > 0 then
    -- Clear existing signs
    vim.fn.sign_unplace("PRComments", { buffer = buf_nr })
    
    local signs_placed = 0  -- Initialize counter
    
    -- Group comments by line and side, then count them
    local comments_by_line = {}
    for _, comment in ipairs(comments) do
      if comment.side == current_side then
        local key = comment.line
        if not comments_by_line[key] then
          comments_by_line[key] = 0
        end
        comments_by_line[key] = comments_by_line[key] + 1
      end
    end
    
    -- Place signs with comment counts
    for line_num, comment_count in pairs(comments_by_line) do
      -- Use number + single ASCII character (2 chars max for sign text)
      local sign_text = comment_count > 9 and "+" or (tostring(comment_count) .. "*")
      local sign_name = comment_count > 9 and "PRC_plus" or string.format("PRC_%d", comment_count)
      
      -- Define the sign if it doesn't exist
      if vim.fn.sign_getdefined(sign_name)[1] == nil then
        vim.fn.sign_define(sign_name, {
          text = sign_text,
          texthl = "PRCommentCount",  -- Custom highlight group for comment counts
        })
      end
      
      -- Validate parameters before placing sign
      if not buf_nr or buf_nr <= 0 then
        vim.notify("Invalid buffer number: " .. tostring(buf_nr), vim.log.levels.ERROR)
        goto continue
      end
      
      if not line_num or line_num <= 0 then
        vim.notify("Invalid line number: " .. tostring(line_num), vim.log.levels.ERROR)
        goto continue
      end
      
      -- Check if buffer is valid
      if not vim.api.nvim_buf_is_valid(buf_nr) then
        vim.notify("Buffer is not valid: " .. tostring(buf_nr), vim.log.levels.ERROR)
        goto continue
      end
      
      -- Check if line exists in buffer
      local line_count = vim.api.nvim_buf_line_count(buf_nr)
      if line_num > line_count then
        vim.notify("Line number " .. line_num .. " exceeds buffer line count " .. line_count, vim.log.levels.ERROR)
        goto continue
      end
      
      -- Place the sign
      local success, err = pcall(vim.fn.sign_place, 0, "PRComments", sign_name, buf_nr, {
        lnum = line_num,
        priority = 10
      })
      
      if not success then
        vim.notify("Failed to place sign: " .. tostring(err) .. " (sign_name=" .. sign_name .. ", bufnr=" .. buf_nr .. ", line=" .. line_num .. ")", vim.log.levels.ERROR)
      else
        signs_placed = signs_placed + 1
      end
      
      ::continue::
    end
  end
end

-- Detect which side of the diff we're currently on (LEFT or RIGHT)
function M.get_diff_side()
  -- In diffview, we can detect the side by checking the buffer name
  local buf_name = vim.api.nvim_buf_get_name(0)
  
  -- Check if we're in a diffview context
  if not buf_name:match("diffview://") then
    -- Not in diffview, assume RIGHT side (new code)
    return "RIGHT"
  end
  
  -- In diffview, the buffer name patterns:
  -- Left side (old): diffview:///path/to/repo/.git/hash/actual/file/path
  -- Right side (new): regular file path or other patterns
  if buf_name:match("^diffview:///") then
    return "LEFT"
  else
    return "RIGHT"
  end
end

-- Refocus the comment window if it's open
function M.refocus_comment_window()
  if _G.pr_comment_window and vim.api.nvim_win_is_valid(_G.pr_comment_window) then
    vim.api.nvim_set_current_win(_G.pr_comment_window)
    -- Position cursor at the end of content (after headers)
    local buf = _G.pr_comment_buffer
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      -- Find the last non-empty line
      local last_line = #lines
      for i = #lines, 1, -1 do
        if lines[i]:match("%S") then
          last_line = i
          break
        end
      end
      vim.api.nvim_win_set_cursor(_G.pr_comment_window, {last_line, #lines[last_line]})
    end
    vim.cmd('startinsert')
    vim.notify("📝 Refocused comment window", vim.log.levels.INFO)
    return true
  else
    vim.notify("No active comment window found", vim.log.levels.WARN)
    return false
  end
end

-- Reply to a specific PR comment
function M.reply_to_comment(original_comment)
  -- Get file and line information from the original comment
  local file_info = {
    file = original_comment.path or M.get_file_and_line().file,
    line = original_comment.line,
    absolute_path = M.get_file_and_line().absolute_path
  }
  
  if not file_info.file then
    vim.notify("Could not determine file information for reply", vim.log.levels.ERROR)
    return
  end
  
  -- Store the current window before opening comment buffer
  local original_win = vim.api.nvim_get_current_win()
  
  -- Get screen dimensions
  local width = vim.o.columns
  local height = math.min(15, math.floor(vim.o.lines * 0.4)) -- Slightly larger for replies
  
  -- Create floating window at bottom of screen
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = vim.o.lines - height,
    col = 0,
    style = 'minimal',
    border = {'─', '─', '─', '', '', '', '─', ''},  -- Only top border
    title = " 💬 Reply to @" .. original_comment.username .. " ",
    title_pos = "left",
  })
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  -- Set window options
  vim.api.nvim_win_set_option(win, 'wrap', true)
  vim.api.nvim_win_set_option(win, 'linebreak', true)
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'cursorline', true)
  
  -- Add helpful header with context
  local header_lines = {
    string.format("Reply to @%s on %s:%d", original_comment.username, file_info.file, file_info.line),
    string.format("Original: %s", (original_comment.body or ""):gsub("\n", " "):sub(1, 60) .. "..."),
    "Write your reply below. Ctrl+S to post, Ctrl+X to cancel, <leader>gf to refocus.",
    "",
    ""
  }
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, header_lines)
  
  -- Store references globally for refocus functionality
  _G.pr_comment_window = win
  _G.pr_comment_buffer = buf
  
  -- Move cursor to the first line after header
  vim.api.nvim_win_set_cursor(win, {5, 0})
  
  -- Enter insert mode
  vim.cmd('startinsert')
  
  -- Create autocommand group
  local group = vim.api.nvim_create_augroup("PRReplyFloating", { clear = true })
  
  -- Function to post reply
  local function post_reply()
    -- Get the reply text (skip header lines)
    local lines = vim.api.nvim_buf_get_lines(buf, 4, -1, false)
    
    -- Remove empty lines from the end
    while #lines > 0 and lines[#lines]:match("^%s*$") do
      table.remove(lines)
    end
    
    local reply_text = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- Clear global references
    _G.pr_comment_window = nil
    _G.pr_comment_buffer = nil
    
    -- Close the floating window
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    
    -- Return focus to original window
    if original_win and vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    
    -- Post the reply
    if reply_text ~= "" then
      M.post_comment_with_confirmation(reply_text, file_info, original_comment.id)
    else
      vim.notify("Reply is empty - not posting", vim.log.levels.INFO)
    end
  end
  
  -- Function to cancel reply
  local function cancel_reply()
    -- Clear global references
    _G.pr_comment_window = nil
    _G.pr_comment_buffer = nil
    
    -- Close the floating window
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    
    -- Return focus to original window
    if original_win and vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    
    vim.notify("Reply cancelled", vim.log.levels.INFO)
  end
  
  -- Set up keymaps for the floating window
  local keymap_opts = { buffer = buf, noremap = true, silent = true }
  
  -- Ctrl+S to post reply
  vim.keymap.set({'n', 'i'}, '<C-s>', function()
    vim.cmd('stopinsert')
    post_reply()
  end, keymap_opts)
  
  -- Ctrl+X to cancel
  vim.keymap.set({'n', 'i'}, '<C-x>', function()
    vim.cmd('stopinsert')
    cancel_reply()
  end, keymap_opts)
  
  -- Escape to cancel (additional convenience)
  vim.keymap.set({'n', 'i'}, '<Esc>', function()
    vim.cmd('stopinsert')
    cancel_reply()
  end, keymap_opts)
  
  -- Clean up on buffer delete
  vim.api.nvim_create_autocmd({"BufWipeout", "BufDelete"}, {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      _G.pr_comment_window = nil
      _G.pr_comment_buffer = nil
      
      if original_win and vim.api.nvim_win_is_valid(original_win) then
        vim.api.nvim_set_current_win(original_win)
      end
    end,
  })
  
  return true
end

-- Clean up displayed images when closing comment windows
function M.cleanup_displayed_images()
  -- TODO: Implement image cleanup when image.nvim is integrated
  -- This will clean up any displayed profile pictures
  return
end

-- Debug function to test image.nvim availability and status
function M.debug_image_nvim()
  vim.notify("=== DEBUG: image.nvim Status ===", vim.log.levels.INFO)
  vim.notify("🔧 image.nvim integration removed - will be implemented later", vim.log.levels.INFO)
  vim.notify("=== END DEBUG ===", vim.log.levels.INFO)
end

-- Debug function to check profile picture cache
function M.debug_profile_pics()
  vim.notify("=== DEBUG: Profile Picture Cache ===", vim.log.levels.INFO)
  
  local cache_dir = M.config.cache_dir .. "/profile_pics"
  vim.notify(string.format("📁 Cache directory: %s", cache_dir), vim.log.levels.INFO)
  
  -- Check if directory exists
  if vim.fn.isdirectory(cache_dir) == 1 then
    vim.notify("✅ Cache directory exists", vim.log.levels.INFO)
    
    -- List cached profile pictures
    local files = vim.fn.glob(cache_dir .. "/*.png", false, true)
    if #files > 0 then
      vim.notify(string.format("🖼️  Found %d cached profile pictures:", #files), vim.log.levels.INFO)
      for _, file in ipairs(files) do
        local filename = vim.fn.fnamemodify(file, ":t:r") -- Just the username
        local size = vim.fn.getfsize(file)
        vim.notify(string.format("  - %s (%d bytes)", filename, size), vim.log.levels.INFO)
      end
    else
      vim.notify("📭 No cached profile pictures found", vim.log.levels.WARN)
    end
  else
    vim.notify("❌ Cache directory does not exist", vim.log.levels.ERROR)
  end
  
  -- Check memory cache
  local memory_count = vim.tbl_count(state.profile_pics_cache)
  vim.notify(string.format("💾 Memory cache: %d entries", memory_count), vim.log.levels.INFO)
  
  vim.notify("🔧 Profile picture display will be implemented later with image.nvim", vim.log.levels.INFO)
  vim.notify("=== END DEBUG ===", vim.log.levels.INFO)
end

-- TODO: Remove test function when image.nvim is properly integrated
function M.test_image_render()
  vim.notify("🔧 Image rendering test removed - will be implemented later with image.nvim", vim.log.levels.INFO)
end

-- Build thread structure from flat comment list
function M.build_comment_threads(comments)
  local threads = {}
  local replies_map = {}
  
  -- First pass: separate root comments from replies
  local root_comments = {}
  local reply_comments = {}
  
  for _, comment in ipairs(comments) do
    if comment.in_reply_to_id then
      table.insert(reply_comments, comment)
    else
      table.insert(root_comments, comment)
    end
  end
  
  -- Build replies map for quick lookup
  for _, reply in ipairs(reply_comments) do
    if not replies_map[reply.in_reply_to_id] then
      replies_map[reply.in_reply_to_id] = {}
    end
    table.insert(replies_map[reply.in_reply_to_id], reply)
  end
  
  -- Sort root comments by creation time (oldest first)
  table.sort(root_comments, function(a, b)
    return (a.created_at or "") < (b.created_at or "")
  end)
  
  -- Build threads with nested replies
  for _, root_comment in ipairs(root_comments) do
    local thread = {
      root = root_comment,
      replies = M.get_nested_replies(root_comment.id, replies_map, {})
    }
    table.insert(threads, thread)
  end
  
  return threads
end

-- Recursively get nested replies for a comment
function M.get_nested_replies(comment_id, replies_map, visited)
  local replies = {}
  
  -- Prevent infinite loops in case of circular references
  if visited[comment_id] then
    return replies
  end
  visited[comment_id] = true
  
  local direct_replies = replies_map[comment_id] or {}
  
  -- Sort replies by creation time (oldest first)
  table.sort(direct_replies, function(a, b)
    return (a.created_at or "") < (b.created_at or "")
  end)
  
  for _, reply in ipairs(direct_replies) do
    table.insert(replies, {
      comment = reply,
      nested_replies = M.get_nested_replies(reply.id, replies_map, visited)
    })
  end
  
  return replies
end

-- Format threaded comment content for display
function M.format_threaded_comment_content(threads)
  local lines = {}
  local all_highlights = {}
  
  for thread_index, thread in ipairs(threads) do
    -- Format root comment (no thread separator box)
    local root_lines, root_highlights = M.format_single_comment(thread.root, 0, thread_index, #threads, true)
    local base_line_offset = #lines
    for _, line in ipairs(root_lines) do
      table.insert(lines, line)
    end
    -- Adjust highlight line offsets and add to main list
    for _, highlight_info in ipairs(root_highlights) do
      table.insert(all_highlights, {
        line_offset = base_line_offset + highlight_info.line_offset,
        highlights = highlight_info.highlights
      })
    end
    
    -- Format replies with nesting
    M.format_nested_replies(thread.replies, 1, lines, all_highlights)
    
    -- Add spacing between threads (except for last thread)
    if thread_index < #threads then
      table.insert(lines, "")
    end
  end
  
  return lines, all_highlights
end

-- Format a single comment with specified indentation level
function M.format_single_comment(comment, indent_level, thread_index, total_threads, is_root)
  local lines = {}
  local highlight_info = {}  -- Track highlighting information
  local indent = string.rep("  ", indent_level)
  
  -- Create tree-like visual structure
  local tree_prefix = ""
  if indent_level == 0 then
    if is_root and total_threads > 1 then
      tree_prefix = string.format("┌─ Thread %d/%d ", thread_index, total_threads)
    else
      tree_prefix = "┌─ "
    end
  else
    tree_prefix = "└─ 💬 "  -- Reply header at far left (no indent)
  end
  
  -- Comment header with user and metadata
  local header = string.format("%s@%s", tree_prefix, comment.username)
  table.insert(lines, header)
  local tree_prefix_bytes = vim.fn.strlen(tree_prefix)
  local header_bytes = vim.fn.strlen(header)
  
  -- Different highlighting for top-level vs replies
  if indent_level == 0 then
    table.insert(highlight_info, {
      line_offset = #lines - 1,
      highlights = {
        { group = "PRCommentHeader", start_col = 0, end_col = tree_prefix_bytes - 1 },
        { group = "PRCommentUsername", start_col = tree_prefix_bytes, end_col = header_bytes - 1 }
      }
    })
  else
    -- For replies, make the └─ part grey and keep username purple
    table.insert(highlight_info, {
      line_offset = #lines - 1,
      highlights = {
        { group = "PRCommentBorder", start_col = 0, end_col = tree_prefix_bytes - 1 },  -- Grey └─ 💬
        { group = "PRCommentUsername", start_col = tree_prefix_bytes, end_col = header_bytes - 1 }
      }
    })
  end
  
  -- Add creation date info with proper indentation (removed side info)
  local meta_indent = indent_level == 0 and "" or "  "  -- No indent for top-level, minimal for replies
  if comment.created_at then
    local date_str = comment.created_at:match("([^T]+)") -- Just the date part
    local time_str = comment.created_at:match("T([^Z]+)") -- Time part
    if time_str then
      time_str = time_str:sub(1, 5) -- Just HH:MM
    end
    local meta_line = string.format("%s📅 %s at %s", meta_indent, date_str, time_str or "unknown")
    table.insert(lines, meta_line)
    local meta_line_bytes = vim.fn.strlen(meta_line)
    table.insert(highlight_info, {
      line_offset = #lines - 1,
      highlights = {
        { group = "PRCommentMeta", start_col = 0, end_col = meta_line_bytes - 1 }
      }
    })
  end
  
  -- Content separator - dynamically sized based on indentation
  local base_box_width = 78  -- Base width for top-level comments  
  local box_width = base_box_width - vim.fn.strchars(meta_indent)  -- Adjust for indentation
  local border_dashes = string.rep("─", box_width - 2)  -- -2 for the corner characters
  local border_line = meta_indent .. "┌" .. border_dashes .. "┐"
  table.insert(lines, border_line)
  local border_line_bytes = vim.fn.strlen(border_line)
  table.insert(highlight_info, {
    line_offset = #lines - 1,
    highlights = {
      { group = "PRCommentBorder", start_col = 0, end_col = border_line_bytes - 1 }
    }
  })
  
  -- Comment body with proper word wrapping and indentation
  local content_indent = meta_indent .. "│"
  local content_width = box_width - 2  -- Adjust to position right border correctly
  local body_lines = vim.split(comment.body, "\n")
  
  -- Calculate proper highlight positions using byte positions for vim highlighting
  local meta_indent_bytes = vim.fn.strlen(meta_indent)
  local border_char_bytes = vim.fn.strlen("│")  -- The box drawing character
  local content_indent_bytes = vim.fn.strlen(content_indent)
  
  for _, line in ipairs(body_lines) do
    if line == "" then
      local empty_line = content_indent .. string.rep(" ", content_width) .. "│"
      table.insert(lines, empty_line)
      local line_length_bytes = vim.fn.strlen(empty_line)
      table.insert(highlight_info, {
        line_offset = #lines - 1,
        highlights = {
          { group = "PRCommentBorder", start_col = 0, end_col = meta_indent_bytes + border_char_bytes - 1 },
          { group = "PRCommentBorder", start_col = line_length_bytes - border_char_bytes, end_col = line_length_bytes - 1 }
        }
      })
    else
      -- Handle long lines by wrapping them to fit available width
      if vim.fn.strchars(line) > content_width then
        local wrapped = {}
        local current_line = ""
        for word in line:gmatch("%S+") do
          if vim.fn.strchars(current_line) + vim.fn.strchars(word) + 1 <= content_width then
            current_line = current_line == "" and word or (current_line .. " " .. word)
          else
            if current_line ~= "" then
              table.insert(wrapped, current_line)
            end
            current_line = word
          end
        end
        if current_line ~= "" then
          table.insert(wrapped, current_line)
        end
        for _, wrapped_text in ipairs(wrapped) do
          local padding = content_width - vim.fn.strchars(wrapped_text)
          local content_line = content_indent .. wrapped_text .. string.rep(" ", padding) .. "│"
          table.insert(lines, content_line)
          local line_length_bytes = vim.fn.strlen(content_line)
          table.insert(highlight_info, {
            line_offset = #lines - 1,
            highlights = {
              { group = "PRCommentBorder", start_col = 0, end_col = meta_indent_bytes + border_char_bytes - 1 },
              { group = "PRCommentContent", start_col = content_indent_bytes, end_col = content_indent_bytes + vim.fn.strlen(wrapped_text) - 1 },
              { group = "PRCommentBorder", start_col = line_length_bytes - border_char_bytes, end_col = line_length_bytes - 1 }
            }
          })
        end
      else
        local padding = content_width - vim.fn.strchars(line)
        local content_line = content_indent .. line .. string.rep(" ", padding) .. "│"
        table.insert(lines, content_line)
        local line_length_bytes = vim.fn.strlen(content_line)
        table.insert(highlight_info, {
          line_offset = #lines - 1,
          highlights = {
            { group = "PRCommentBorder", start_col = 0, end_col = meta_indent_bytes + border_char_bytes - 1 },
            { group = "PRCommentContent", start_col = content_indent_bytes, end_col = content_indent_bytes + vim.fn.strlen(line) - 1 },
            { group = "PRCommentBorder", start_col = line_length_bytes - border_char_bytes, end_col = line_length_bytes - 1 }
          }
        })
      end
    end
  end
  
  -- Content footer - adjust length to match content width
  local footer_dashes = string.rep("─", box_width - 2)  -- -2 for the corner characters
  local footer_line = meta_indent .. "└" .. footer_dashes .. "┘"
  table.insert(lines, footer_line)
  local footer_line_bytes = vim.fn.strlen(footer_line)
  table.insert(highlight_info, {
    line_offset = #lines - 1,
    highlights = {
      { group = "PRCommentBorder", start_col = 0, end_col = footer_line_bytes - 1 }
    }
  })
  
  return lines, highlight_info
end

-- Format nested replies recursively
function M.format_nested_replies(replies, indent_level, lines, all_highlights)
  for reply_index, reply_data in ipairs(replies) do
    -- Add spacing before nested replies, but not too much
    if reply_index == 1 then
      table.insert(lines, "│")
      table.insert(all_highlights, {
        line_offset = #lines - 1,
        highlights = {
          { group = "PRCommentBorder", start_col = 0, end_col = vim.fn.strlen("│") - 1 }
        }
      })
    end
    
    -- Format the reply comment
    local reply_lines, reply_highlights = M.format_single_comment(reply_data.comment, indent_level, 0, 0, false)
    local base_line_offset = #lines
    for _, line in ipairs(reply_lines) do
      table.insert(lines, line)
    end
    -- Adjust highlight line offsets and add to main list
    for _, highlight_info in ipairs(reply_highlights) do
      table.insert(all_highlights, {
        line_offset = base_line_offset + highlight_info.line_offset,
        highlights = highlight_info.highlights
      })
    end
    
    -- Recursively format nested replies (though GitHub doesn't support deep nesting)
    if #reply_data.nested_replies > 0 then
      M.format_nested_replies(reply_data.nested_replies, indent_level + 1, lines, all_highlights)
    end
  end
end

-- Navigate to next/previous comment line
function M.goto_next_comment()
  local file_info = M.get_file_and_line()
  if not file_info then
    vim.notify("Could not determine file information", vim.log.levels.WARN)
    return
  end
  
  local comments = state.comments_cache[file_info.file]
  if not comments or #comments == 0 then
    vim.notify("No comments found in this file", vim.log.levels.INFO)
    return
  end
  
  local current_side = M.get_diff_side()
  local current_line = file_info.line
  
  -- Get all comment lines for current side, sorted
  local comment_lines = {}
  for _, comment in ipairs(comments) do
    if comment.side == current_side and type(comment.line) == "number" then
      comment_lines[comment.line] = true
    end
  end
  
  -- Convert to sorted array
  local sorted_lines = {}
  for line_num, _ in pairs(comment_lines) do
    table.insert(sorted_lines, line_num)
  end
  table.sort(sorted_lines)
  
  if #sorted_lines == 0 then
    vim.notify(string.format("No comments on %s side", current_side), vim.log.levels.INFO)
    return
  end
  
  -- Find next line after current
  local next_line = nil
  for _, line_num in ipairs(sorted_lines) do
    if line_num > current_line then
      next_line = line_num
      break
    end
  end
  
  -- If no next line found, wrap to first
  if not next_line then
    next_line = sorted_lines[1]
    vim.notify("Wrapped to first comment", vim.log.levels.INFO)
  end
  
  -- Jump to the line
  vim.api.nvim_win_set_cursor(0, {next_line, 0})
  vim.notify(string.format("Jumped to comment on line %d", next_line), vim.log.levels.INFO)
end

function M.goto_prev_comment()
  local file_info = M.get_file_and_line()
  if not file_info then
    vim.notify("Could not determine file information", vim.log.levels.WARN)
    return
  end
  
  local comments = state.comments_cache[file_info.file]
  if not comments or #comments == 0 then
    vim.notify("No comments found in this file", vim.log.levels.INFO)
    return
  end
  
  local current_side = M.get_diff_side()
  local current_line = file_info.line
  
  -- Get all comment lines for current side, sorted
  local comment_lines = {}
  for _, comment in ipairs(comments) do
    if comment.side == current_side and type(comment.line) == "number" then
      comment_lines[comment.line] = true
    end
  end
  
  -- Convert to sorted array (reverse order for previous)
  local sorted_lines = {}
  for line_num, _ in pairs(comment_lines) do
    table.insert(sorted_lines, line_num)
  end
  table.sort(sorted_lines, function(a, b) return a > b end) -- Reverse sort
  
  if #sorted_lines == 0 then
    vim.notify(string.format("No comments on %s side", current_side), vim.log.levels.INFO)
    return
  end
  
  -- Find previous line before current
  local prev_line = nil
  for _, line_num in ipairs(sorted_lines) do
    if line_num < current_line then
      prev_line = line_num
      break
    end
  end
  
  -- If no previous line found, wrap to last
  if not prev_line then
    prev_line = sorted_lines[#sorted_lines]
    vim.notify("Wrapped to last comment", vim.log.levels.INFO)
  end
  
  -- Jump to the line
  vim.api.nvim_win_set_cursor(0, {prev_line, 0})
  vim.notify(string.format("Jumped to comment on line %d", prev_line), vim.log.levels.INFO)
end

-- Auto-preview functions
function M.close_auto_preview()
  local preview_state = state.auto_preview
  
  -- Don't close if we're in the middle of creating a preview
  if preview_state.creating then
    return
  end
  
  if preview_state.current_win and vim.api.nvim_win_is_valid(preview_state.current_win) then
    vim.api.nvim_win_close(preview_state.current_win, true)
  end
  
  -- Restore original layout (sidebar, window sizes)
  M.restore_layout_from_preview()
  
  preview_state.current_win = nil
  preview_state.current_buf = nil
  preview_state.current_line = nil
  preview_state.current_file = nil
end

-- Update content of existing preview window (for comment-to-comment transitions)
function M.update_preview_content(file_path, line_num, side)
  local preview_state = state.auto_preview
  
  if not preview_state.current_win or not vim.api.nvim_win_is_valid(preview_state.current_win) then
    return
  end
  
  local comments = state.comments_cache[file_path]
  if not comments then
    return
  end
  
  -- Filter comments for current line and side
  local line_comments = {}
  for _, comment in ipairs(comments) do
    if comment.line == line_num and comment.side == side then
      table.insert(line_comments, comment)
    end
  end
  
  if #line_comments == 0 then
    return
  end
  
  -- Build thread structure
  local threads = M.build_comment_threads(line_comments)
  if #threads == 0 then
    return
  end
  
  local buf = preview_state.current_buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  
  -- Make buffer temporarily modifiable
  vim.api.nvim_buf_set_option(buf, 'modifiable', true)
  
  -- Format and display threaded comments (same as show_auto_preview)
  local all_lines = {}
  
  -- Simpler header for preview
  table.insert(all_lines, string.format("💬 Comments: %s:%d", file_path, line_num))
  table.insert(all_lines, "")
  
  local header_line_count = #all_lines
  
  -- Format threaded comments
  local thread_lines, highlight_info = M.format_threaded_comment_content(threads)
  for _, line in ipairs(thread_lines) do
    table.insert(all_lines, line)
  end
  
  -- Update buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  
  -- Clear existing highlights and apply new ones
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  
  -- Apply syntax highlighting
  for _, highlight_data in ipairs(highlight_info) do
    local line_idx = header_line_count + highlight_data.line_offset
    for _, hl in ipairs(highlight_data.highlights) do
      if hl.start_col <= hl.end_col and line_idx >= 0 and line_idx < #all_lines then
        vim.api.nvim_buf_add_highlight(buf, -1, hl.group, line_idx, hl.start_col, hl.end_col + 1)
      end
    end
  end
  
  -- Apply header highlighting
  vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentHeader", 0, 0, -1)
  
  -- Make buffer read-only again
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Update state
  preview_state.current_line = line_num
  preview_state.current_file = file_path
end

function M.show_auto_preview(file_path, line_num, side)
  local preview_state = state.auto_preview
  
  -- Set flag to prevent closing during creation
  preview_state.creating = true
  
  -- Close existing preview if different line/file
  if preview_state.current_line ~= line_num or preview_state.current_file ~= file_path then
    -- Temporarily allow closing for cleanup
    preview_state.creating = false
    M.close_auto_preview()
    preview_state.creating = true
  end
  
  -- Don't show if already showing the same content
  if preview_state.current_line == line_num and preview_state.current_file == file_path then
    preview_state.creating = false
    return
  end
  
  local comments = state.comments_cache[file_path]
  if not comments then
    preview_state.creating = false
    return
  end
  
  -- Filter comments for current line and side
  local line_comments = {}
  for _, comment in ipairs(comments) do
    if comment.line == line_num and comment.side == side then
      table.insert(line_comments, comment)
    end
  end
  
  if #line_comments == 0 then
    preview_state.creating = false
    return
  end
  
  -- Build thread structure
  local threads = M.build_comment_threads(line_comments)
  if #threads == 0 then
    preview_state.creating = false
    return
  end
  
  -- Create left-side preview window first
  local buf, win, original_win = M.create_left_preview_window(line_comments)
  
  if not win or not vim.api.nvim_win_is_valid(win) then
    preview_state.creating = false
    return
  end
  
  -- Format and display threaded comments
  local all_lines = {}
  
  -- Simpler header for preview
  table.insert(all_lines, string.format("💬 Comments: %s:%d", file_path, line_num))
  table.insert(all_lines, "")
  
  local header_line_count = #all_lines
  
  -- Format threaded comments
  local thread_lines, highlight_info = M.format_threaded_comment_content(threads)
  for _, line in ipairs(thread_lines) do
    table.insert(all_lines, line)
  end
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  
  -- Apply syntax highlighting
  for _, highlight_data in ipairs(highlight_info) do
    local line_idx = header_line_count + highlight_data.line_offset
    for _, hl in ipairs(highlight_data.highlights) do
      if hl.start_col <= hl.end_col and line_idx >= 0 and line_idx < #all_lines then
        vim.api.nvim_buf_add_highlight(buf, -1, hl.group, line_idx, hl.start_col, hl.end_col + 1)
      end
    end
  end
  
  -- Apply header highlighting
  vim.api.nvim_buf_add_highlight(buf, -1, "PRCommentHeader", 0, 0, -1)
  
  -- Make buffer read-only
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)
  
  -- Store state
  preview_state.current_win = win
  preview_state.current_buf = buf
  preview_state.current_line = line_num
  preview_state.current_file = file_path
  
  -- Return focus to original window
  if original_win and vim.api.nvim_win_is_valid(original_win) then
    vim.api.nvim_set_current_win(original_win)
  end
  
  -- NOW handle layout (close file panel) at the very end
  M.save_layout_for_preview()
  M.setup_preview_layout()
  
  -- Clear creating flag - preview is now ready
  preview_state.creating = false
end

function M.handle_cursor_moved()
  if not M.config.auto_preview.enable then
    return
  end
  
  local file_info = M.get_file_and_line()
  if not file_info then
    M.close_auto_preview()
    return
  end
  
  local comments = state.comments_cache[file_info.file]
  if not comments then
    M.close_auto_preview()
    return
  end
  
  local current_side = M.get_diff_side()
  local has_comments = false
  
  -- Check if current line has comments
  for _, comment in ipairs(comments) do
    if comment.line == file_info.line and comment.side == current_side then
      has_comments = true
      break
    end
  end
  
  local preview_state = state.auto_preview
  
  if has_comments then
    -- Check if we're already showing a preview for this exact line and file
    if preview_state.current_line == file_info.line and 
       preview_state.current_file == file_info.file then
      return -- Already showing the right content
    end
    
    -- If we're transitioning from one commented line to another, update preview content directly
    if preview_state.current_win and vim.api.nvim_win_is_valid(preview_state.current_win) and
       preview_state.current_file == file_info.file then
      -- Cancel any pending timer
      if preview_state.timer then
        preview_state.timer:stop()
        preview_state.timer = nil
      end
      
      -- Update the preview immediately without closing/reopening
      M.update_preview_content(file_info.file, file_info.line, current_side)
      return
    end
    
    -- Show preview with delay for new lines
    -- Cancel existing timer
    if preview_state.timer then
      preview_state.timer:stop()
      preview_state.timer = nil
    end
    
    -- Set new timer
    preview_state.timer = vim.defer_fn(function()
      M.show_auto_preview(file_info.file, file_info.line, current_side)
      preview_state.timer = nil
    end, M.config.auto_preview.delay_ms)
  else
    -- Close preview
    M.close_auto_preview()
  end
end

-- Toggle auto-preview feature
function M.toggle_auto_preview()
  M.config.auto_preview.enable = not M.config.auto_preview.enable
  
  if M.config.auto_preview.enable then
    vim.notify("✅ Auto-preview enabled - comments will show automatically", vim.log.levels.INFO)
    -- Trigger immediate check
    M.handle_cursor_moved()
  else
    vim.notify("❌ Auto-preview disabled", vim.log.levels.INFO)
    M.close_auto_preview()
  end
end

-- Auto-preview layout management
function M.save_layout_for_preview()
  local preview_state = state.auto_preview
  
  if preview_state.layout_saved then
    return -- Already saved
  end
  
  -- Store the current window to restore focus later
  local current_win = vim.api.nvim_get_current_win()
  preview_state.original_window = current_win
  
  -- Also store buffer and cursor info as backup
  if vim.api.nvim_win_is_valid(current_win) then
    preview_state.original_buffer = vim.api.nvim_win_get_buf(current_win)
    preview_state.original_cursor = vim.api.nvim_win_get_cursor(current_win)
  end
  
  -- Check if we're in diffview and if file panel is open
  local diffview_lib = require("diffview.lib")
  local view = diffview_lib.get_current_view()
  
  if view and view.panel then
    preview_state.sidebar_was_open = view.panel:is_open()
  else
    preview_state.sidebar_was_open = false
  end
  
  preview_state.layout_saved = true
end

function M.setup_preview_layout()
  local preview_state = state.auto_preview
  
  -- Close file panel if it's open (we'll replace it with preview)
  if preview_state.sidebar_was_open then
    -- Use diffview API directly
    local diffview_actions = require("diffview.actions")
    local diffview_lib = require("diffview.lib")
    local view = diffview_lib.get_current_view()
    
    if view and view.panel and view.panel:is_open() then
      diffview_actions.toggle_files()
    end
  end
end

function M.restore_layout_from_preview()
  local preview_state = state.auto_preview
  
  if not preview_state.layout_saved then
    return -- Nothing to restore
  end
  
  -- Restore file panel if it was open
  if preview_state.sidebar_was_open then
    local diffview_lib = require("diffview.lib")
    local view = diffview_lib.get_current_view()
    
    -- Only open if we're in diffview and panel is currently closed
    if view and view.panel and not view.panel:is_open() then
      -- Use panel:open() directly instead of toggle_files() to avoid automatic focus
      view.panel:open()
      
      -- Now restore focus to original window immediately
      if preview_state.original_window and vim.api.nvim_win_is_valid(preview_state.original_window) then
        vim.api.nvim_set_current_win(preview_state.original_window)
      elseif preview_state.original_buffer and vim.api.nvim_buf_is_valid(preview_state.original_buffer) then
        -- Backup method: find window by buffer
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == preview_state.original_buffer then
            vim.api.nvim_set_current_win(win)
            if preview_state.original_cursor then
              vim.api.nvim_win_set_cursor(win, preview_state.original_cursor)
            end
            break
          end
        end
      end
    end
  end
  
  -- Reset layout state
  preview_state.layout_saved = false
  preview_state.sidebar_was_open = false
  preview_state.original_window = nil
  preview_state.original_buffer = nil
  preview_state.original_cursor = nil
end

-- Explicit comment view layout management (for <leader>gv)
function M.save_explicit_layout()
  -- Reuse the auto_preview state but mark it as explicit
  local preview_state = state.auto_preview
  
  if preview_state.layout_saved then
    return -- Already saved
  end
  
  -- Store the current window to restore focus later
  local current_win = vim.api.nvim_get_current_win()
  preview_state.original_window = current_win
  
  -- Also store buffer and cursor info as backup
  if vim.api.nvim_win_is_valid(current_win) then
    preview_state.original_buffer = vim.api.nvim_win_get_buf(current_win)
    preview_state.original_cursor = vim.api.nvim_win_get_cursor(current_win)
  end
  
  -- Check if we're in diffview and if file panel is open
  local diffview_lib = require("diffview.lib")
  local view = diffview_lib.get_current_view()
  
  if view and view.panel then
    preview_state.sidebar_was_open = view.panel:is_open()
  else
    preview_state.sidebar_was_open = false
  end
  
  preview_state.layout_saved = true
  preview_state.is_explicit = true  -- Mark as explicit view
end

function M.setup_explicit_layout()
  local preview_state = state.auto_preview
  
  -- Close file panel if it's open 
  if preview_state.sidebar_was_open then
    -- Use diffview API directly (same as working auto-preview code)
    local diffview_actions = require("diffview.actions")
    local diffview_lib = require("diffview.lib")
    local view = diffview_lib.get_current_view()
    
    if view and view.panel and view.panel:is_open() then
      diffview_actions.toggle_files()
    end
  end
  
  -- Resize the left two windows to be equal width
  vim.defer_fn(function()
    M.resize_left_windows_for_explicit_view()
  end, 100) -- Small delay to let diffview complete panel operations
end

function M.resize_left_windows_for_explicit_view()
  -- Get all normal windows (not floating)
  local wins = vim.api.nvim_list_wins()
  local normal_wins = {}
  
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      local config = vim.api.nvim_win_get_config(win)
      if config.relative == "" then -- Only normal windows, not floating
        table.insert(normal_wins, win)
      end
    end
  end
  
  -- We want to resize the left two windows to be equal
  -- Assuming 3 windows total: left diff, right diff, comment view
  if #normal_wins >= 3 then
    local total_width = vim.o.columns
    local left_width = math.floor(total_width * 0.35)  -- 35% each for left windows
    local right_width = math.floor(total_width * 0.30)  -- 30% for comment view
    
    -- Resize first two windows (left side)
    for i = 1, math.min(2, #normal_wins - 1) do  -- Leave last window for comments
      pcall(vim.api.nvim_win_set_width, normal_wins[i], left_width)
    end
  end
end

function M.restore_explicit_layout()
  local preview_state = state.auto_preview
  
  if not preview_state.layout_saved or not preview_state.is_explicit then
    return -- Nothing to restore or not an explicit view
  end
  
  -- Restore file panel if it was open
  if preview_state.sidebar_was_open then
    local diffview_lib = require("diffview.lib")
    local view = diffview_lib.get_current_view()
    
    if view and view.panel and not view.panel:is_open() then
      view.panel:open()
      
      -- Restore focus to original window after a short delay
      vim.defer_fn(function()
        if preview_state.original_window and vim.api.nvim_win_is_valid(preview_state.original_window) then
          vim.api.nvim_set_current_win(preview_state.original_window)
        elseif preview_state.original_buffer and vim.api.nvim_buf_is_valid(preview_state.original_buffer) then
          -- Backup method: find window by buffer
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == preview_state.original_buffer then
              vim.api.nvim_set_current_win(win)
              if preview_state.original_cursor then
                vim.api.nvim_win_set_cursor(win, preview_state.original_cursor)
              end
              break
            end
          end
        end
      end, 150)
    end
  end
  
  -- Restore auto-preview state if it was saved
  if preview_state.saved_auto_state ~= nil then
    local was_enabled = preview_state.saved_auto_state
    M.config.auto_preview.enable = was_enabled
    
    if was_enabled then
      vim.notify("🔄 Restored auto-preview to enabled state", vim.log.levels.INFO)
      -- Trigger immediate check to show auto-preview if cursor is on a commented line
      vim.defer_fn(function()
        M.handle_cursor_moved()
      end, 300) -- Small delay to let layout settle
    else
      vim.notify("🔄 Restored auto-preview to disabled state", vim.log.levels.INFO)
    end
    
    preview_state.saved_auto_state = nil -- Clear the saved state
  end
  
  -- Reset layout state
  preview_state.layout_saved = false
  preview_state.sidebar_was_open = false
  preview_state.original_window = nil
  preview_state.original_buffer = nil
  preview_state.original_cursor = nil
  preview_state.is_explicit = false
end

-- View PR File Comment Summary
function M.view_pr_file_summary()
  local pr_number = M.get_current_pr()
  if not pr_number then
    vim.notify("❌ No active PR found. Cannot show file summary.", vim.log.levels.WARN)
    return
  end

  if vim.tbl_isempty(state.comments_cache) then
    vim.notify("ℹ️ Comment cache is empty. Please refresh comments first (e.g., with <leader>gR).", vim.log.levels.INFO)
    return
  end

  vim.notify("📊 Generating PR file comment summary...", vim.log.levels.INFO)

  local pr_files = M.get_pr_files()
  if #pr_files == 0 then
    vim.notify("📁 No files found in the current PR.", vim.log.levels.INFO)
    return
  end

  local summary_lines = {}
  local highlight_rules = {}

  local function add_highlight_rule(line_idx, group, start_byte, end_byte)
    table.insert(highlight_rules, {
      line_offset = line_idx,
      group = group,
      start_col = start_byte,
      end_col = end_byte
    })
  end

  -- Line 1: Header
  local header_text = "╭─📊 PR File Comment Summary ─╮"
  table.insert(summary_lines, header_text)
  add_highlight_rule(#summary_lines - 1, "PRCommentHeader", 0, vim.fn.strlen(header_text))

  -- Line 2: PR Info
  local pr_info_text = string.format("├─ PR #%d: %d files", pr_number, #pr_files)
  table.insert(summary_lines, pr_info_text)
  add_highlight_rule(#summary_lines - 1, "PRCommentMeta", 0, vim.fn.strlen(pr_info_text))

  -- Line 3: Border
  local border_char = "│"
  table.insert(summary_lines, border_char)
  add_highlight_rule(#summary_lines - 1, "PRCommentBorder", 0, vim.fn.strlen(border_char))

  local total_left_comments = 0
  local total_right_comments = 0
  local files_with_comments_count = 0

  for _, file_path in ipairs(pr_files) do
    local file_comments_list = state.comments_cache[file_path] or {}
    local left_count = 0
    local right_count = 0

    for _, comment in ipairs(file_comments_list) do
      if comment.side == "LEFT" then
        left_count = left_count + 1
      elseif comment.side == "RIGHT" then
        right_count = right_count + 1
      end
    end

    if left_count > 0 or right_count > 0 then
      files_with_comments_count = files_with_comments_count + 1
    end
    total_left_comments = total_left_comments + left_count
    total_right_comments = total_right_comments + right_count

    -- File Path Line
    local line_idx_file = #summary_lines
    local s_fp_prefix = "├─📄 "
    local s_fp_suffix = ":"
    local file_line_text = s_fp_prefix .. file_path .. s_fp_suffix
    table.insert(summary_lines, file_line_text)
    local current_byte_pos_fp = 0
    add_highlight_rule(line_idx_file, "PRCommentBorder", current_byte_pos_fp, current_byte_pos_fp + vim.fn.strlen(s_fp_prefix:sub(1,1))) -- ├
    current_byte_pos_fp = current_byte_pos_fp + vim.fn.strlen(s_fp_prefix:sub(1,1))
    add_highlight_rule(line_idx_file, "PRCommentHeader", current_byte_pos_fp, current_byte_pos_fp + vim.fn.strlen(s_fp_prefix:sub(2))) -- ─📄 
    current_byte_pos_fp = current_byte_pos_fp + vim.fn.strlen(s_fp_prefix:sub(2))
    add_highlight_rule(line_idx_file, "PRCommentHeader", current_byte_pos_fp, current_byte_pos_fp + vim.fn.strlen(file_path)) -- filepath
    current_byte_pos_fp = current_byte_pos_fp + vim.fn.strlen(file_path)
    add_highlight_rule(line_idx_file, "PRCommentHeader", current_byte_pos_fp, current_byte_pos_fp + vim.fn.strlen(s_fp_suffix)) -- :
    
    -- Comment Count Line
    local line_idx_count = #summary_lines
    local s_cc_border1 = "│"
    local s_cc_pad1 = "      "
    local s_cc_left_label = "Left: "
    local s_cc_left_val = string.format("%-3d", left_count)
    local s_cc_sep_pad = " "
    local s_cc_sep = "┊"
    local s_cc_pad2 = " "
    local s_cc_right_label = "Right: "
    local s_cc_right_val = string.format("%-3d", right_count)
    local s_cc_suffix = " comments"
    
    local count_line_text = s_cc_border1 .. s_cc_pad1 .. s_cc_left_label .. s_cc_left_val .. s_cc_sep_pad .. s_cc_sep .. s_cc_pad2 .. s_cc_right_label .. s_cc_right_val .. s_cc_suffix
    table.insert(summary_lines, count_line_text)
    local current_byte_pos_cc = 0

    add_highlight_rule(line_idx_count, "PRCommentBorder", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_border1))
    current_byte_pos_cc = current_byte_pos_cc + vim.fn.strlen(s_cc_border1)
    add_highlight_rule(line_idx_count, "PRCommentContent", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_pad1 .. s_cc_left_label))
    current_byte_pos_cc = current_byte_pos_cc + vim.fn.strlen(s_cc_pad1 .. s_cc_left_label)
    add_highlight_rule(line_idx_count, "PRCommentCount", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_left_val))
    current_byte_pos_cc = current_byte_pos_cc + vim.fn.strlen(s_cc_left_val)
    add_highlight_rule(line_idx_count, "PRCommentContent", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_sep_pad))
    current_byte_pos_cc = current_byte_pos_cc + vim.fn.strlen(s_cc_sep_pad)
    add_highlight_rule(line_idx_count, "PRCommentBorder", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_sep))
    current_byte_pos_cc = current_byte_pos_cc + vim.fn.strlen(s_cc_sep)
    add_highlight_rule(line_idx_count, "PRCommentContent", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_pad2 .. s_cc_right_label))
    current_byte_pos_cc = current_byte_pos_cc + vim.fn.strlen(s_cc_pad2 .. s_cc_right_label)
    add_highlight_rule(line_idx_count, "PRCommentCount", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_right_val))
    current_byte_pos_cc = current_byte_pos_cc + vim.fn.strlen(s_cc_right_val)
    add_highlight_rule(line_idx_count, "PRCommentContent", current_byte_pos_cc, current_byte_pos_cc + vim.fn.strlen(s_cc_suffix))
  end

  -- Totals Section Border
  table.insert(summary_lines, border_char)
  add_highlight_rule(#summary_lines - 1, "PRCommentBorder", 0, vim.fn.strlen(border_char))
  
  -- Total Line 1 (Left/Right)
  local line_idx_total1 = #summary_lines
  local s_t1_prefix = "├─ Total Left: "
  local s_t1_left_val = tostring(total_left_comments)
  local s_t1_infix = ", Total Right: "
  local s_t1_right_val = tostring(total_right_comments)
  local total_line_1 = s_t1_prefix .. s_t1_left_val .. s_t1_infix .. s_t1_right_val
  table.insert(summary_lines, total_line_1)
  local current_byte_pos_t1 = 0
  add_highlight_rule(line_idx_total1, "PRCommentMeta", current_byte_pos_t1, current_byte_pos_t1 + vim.fn.strlen(s_t1_prefix))
  current_byte_pos_t1 = current_byte_pos_t1 + vim.fn.strlen(s_t1_prefix)
  add_highlight_rule(line_idx_total1, "PRCommentCount", current_byte_pos_t1, current_byte_pos_t1 + vim.fn.strlen(s_t1_left_val))
  current_byte_pos_t1 = current_byte_pos_t1 + vim.fn.strlen(s_t1_left_val)
  add_highlight_rule(line_idx_total1, "PRCommentMeta", current_byte_pos_t1, current_byte_pos_t1 + vim.fn.strlen(s_t1_infix))
  current_byte_pos_t1 = current_byte_pos_t1 + vim.fn.strlen(s_t1_infix)
  add_highlight_rule(line_idx_total1, "PRCommentCount", current_byte_pos_t1, current_byte_pos_t1 + vim.fn.strlen(s_t1_right_val))

  -- Total Line 2 (Comments/Files)
  local line_idx_total2 = #summary_lines
  local total_comments_val = total_left_comments + total_right_comments
  local s_t2_prefix = "├─ Total Comments: "
  local s_t2_comments_val = tostring(total_comments_val)
  local s_t2_infix = " on "
  local s_t2_files_val = tostring(files_with_comments_count)
  local s_t2_suffix = " file(s)"
  local total_line_2 = s_t2_prefix .. s_t2_comments_val .. s_t2_infix .. s_t2_files_val .. s_t2_suffix
  table.insert(summary_lines, total_line_2)
  local current_byte_pos_t2 = 0
  add_highlight_rule(line_idx_total2, "PRCommentMeta", current_byte_pos_t2, current_byte_pos_t2 + vim.fn.strlen(s_t2_prefix))
  current_byte_pos_t2 = current_byte_pos_t2 + vim.fn.strlen(s_t2_prefix)
  add_highlight_rule(line_idx_total2, "PRCommentCount", current_byte_pos_t2, current_byte_pos_t2 + vim.fn.strlen(s_t2_comments_val))
  current_byte_pos_t2 = current_byte_pos_t2 + vim.fn.strlen(s_t2_comments_val)
  add_highlight_rule(line_idx_total2, "PRCommentMeta", current_byte_pos_t2, current_byte_pos_t2 + vim.fn.strlen(s_t2_infix))
  current_byte_pos_t2 = current_byte_pos_t2 + vim.fn.strlen(s_t2_infix)
  add_highlight_rule(line_idx_total2, "PRCommentCount", current_byte_pos_t2, current_byte_pos_t2 + vim.fn.strlen(s_t2_files_val))
  current_byte_pos_t2 = current_byte_pos_t2 + vim.fn.strlen(s_t2_files_val)
  add_highlight_rule(line_idx_total2, "PRCommentMeta", current_byte_pos_t2, current_byte_pos_t2 + vim.fn.strlen(s_t2_suffix))

  -- Final Border
  local footer_text = "╰─────────────────────────────╯"
  table.insert(summary_lines, footer_text)
  add_highlight_rule(#summary_lines -1, "PRCommentBorder", 0, vim.fn.strlen(footer_text))

  -- Create window for summary
  local width = 60 -- Hardcoded narrow width
  local max_height = math.floor(vim.o.lines * 0.9)
  local calculated_height = #summary_lines + 2 
  local height = math.min(calculated_height, max_height)

  local original_win = vim.api.nvim_get_current_win()

  local win_config = {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = M.config.floating_window.border or "rounded",
    title = " PR File Summary ",
    title_pos = "center",
    focusable = true,
    zindex = 50
  }

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, win_config)

  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal,FloatBorder:PRCommentBorder')

  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'swapfile', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_name(buf, 'PR File Summary')

  vim.api.nvim_win_set_option(win, 'wrap', false)
  vim.api.nvim_win_set_option(win, 'linebreak', false)
  vim.api.nvim_win_set_option(win, 'cursorline', false)
  vim.api.nvim_win_set_option(win, 'number', false)
  vim.api.nvim_win_set_option(win, 'relativenumber', false)
  vim.api.nvim_win_set_option(win, 'signcolumn', 'no')
  vim.api.nvim_win_set_option(win, 'winfixwidth', true)
  vim.api.nvim_win_set_option(win, 'winfixheight', true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, summary_lines)
  
  for _, hl_rule in ipairs(highlight_rules) do
    vim.api.nvim_buf_add_highlight(buf, -1, hl_rule.group, hl_rule.line_offset, hl_rule.start_col, hl_rule.end_col)
  end

  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'readonly', true)

  local function close_summary_window()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if original_win and vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
  end

  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
    callback = close_summary_window,
    noremap = true, silent = true, desc = 'Close PR File Summary'
  })
  vim.api.nvim_buf_set_keymap(buf, 'n', '<Esc>', '', {
    callback = close_summary_window,
    noremap = true, silent = true, desc = 'Close PR File Summary'
  })

  vim.api.nvim_create_autocmd({"BufLeave", "WinLeave"}, {
    buffer = buf,
    callback = close_summary_window,
    once = true
  })
  
  vim.api.nvim_set_current_win(win)

  vim.notify("✅ PR File Comment Summary displayed.", vim.log.levels.INFO)
end

-- Export functions for external use
return M
