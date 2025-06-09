local M = {}

--[[
Dashboard Plugin with Diagnostic Information

This dashboard displays repository information including:
- Recent git commits with syntax highlighting
- Bookmarks with diagnostic information
- Recent files with diagnostic counts  
- Git hotspots (most changed files) with diagnostics
- Pull requests from GitHub
- Quick actions and keybindings

DIAGNOSTIC FEATURES:
- Shows LSP diagnostic counts for files in bookmarks, recent files, and hotspots
- Displays error (🔴), warning (🟡), info (🔵), and hint (🟢) counts
- Only shows diagnostics for files that are currently loaded or have cached diagnostics
- Can be disabled by setting show_diagnostics = false in config

DIAGNOSTIC DISPLAY FORMAT:
- Files with diagnostics show: "filename [E2 W1 I3 H1]" 
- Colors: Red for errors, Yellow for warnings, Blue for info, Green for hints
- Icons in help section show the diagnostic symbols used

CONFIGURATION:
- show_diagnostics: true/false (default: true) - Enable/disable diagnostic display
- All other existing configuration options remain the same

REQUIREMENTS:
- LSP must be configured and running for diagnostic information
- Files must be opened at least once for diagnostics to be available
- Works with any LSP server that provides vim.diagnostic information
--]]

-- Default configuration
local default_config = {
  auto_open = true, -- Auto-open dashboard when starting nvim
  git_max_commits = 5,
  max_recent_edits = 8,
  max_bookmarks = 8,
  max_hotspot_files = 8,
  max_recent_prs_created = 5,
  max_recent_prs_updated = 5,
  width = 80,
  height = 30,
  show_diagnostics = true, -- Show diagnostic information for files
}

local config = {}

-- Highlighting namespace for dashboard
local dashboard_ns = vim.api.nvim_create_namespace("dashboard_highlights")

-- Define highlight groups for syntax highlighting
local function setup_highlight_groups()
  -- Define commit hash highlight group - using a nice blue that stands out but isn't harsh
  vim.api.nvim_set_hl(0, "DashboardCommitHash", {
    fg = "#83a598",  -- Soft blue from Gruvbox palette - easier on eyes than bright orange
    bold = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 109,   -- Soft blue in 256-color terminals
    cterm = { bold = true }
  })
  
  -- Commit message highlighting - using a pleasant green that's not too bright
  vim.api.nvim_set_hl(0, "DashboardCommitMessage", {
    fg = "#b8bb26",  -- Bright green from Gruvbox - more prominent than beige
    -- Add fallback for terminals that don't support true color
    ctermfg = 142    -- Green in 256-color terminals
  })
  
  -- Author and timestamp highlighting - subtle but still visible
  vim.api.nvim_set_hl(0, "DashboardCommitMeta", {
    fg = "#665c54",  -- Darker gray from Gruvbox - subtle but readable
    italic = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 241,   -- Dark gray in 256-color terminals
    cterm = { italic = true }
  })
  
  -- Bookmark highlighting groups
  vim.api.nvim_set_hl(0, "DashboardBookmarkNumber", {
    fg = "#d3869b",  -- Purple from Gruvbox - stands out for bookmark numbers
    bold = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 175,   -- Purple in 256-color terminals
    cterm = { bold = true }
  })
  
  vim.api.nvim_set_hl(0, "DashboardBookmarkName", {
    fg = "#fabd2f",  -- Yellow/orange from Gruvbox - prominent for bookmark names
    -- Add fallback for terminals that don't support true color
    ctermfg = 214    -- Orange in 256-color terminals
  })
  
  vim.api.nvim_set_hl(0, "DashboardBookmarkPath", {
    fg = "#83a598",  -- Soft blue - same as commit hashes for consistency
    -- Add fallback for terminals that don't support true color
    ctermfg = 109    -- Soft blue in 256-color terminals
  })
  
  vim.api.nvim_set_hl(0, "DashboardBookmarkLine", {
    fg = "#fe8019",  -- Bright orange from Gruvbox - highlights line numbers
    bold = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 208,   -- Bright orange in 256-color terminals
    cterm = { bold = true }
  })
  
  -- Recent Files highlighting groups
  vim.api.nvim_set_hl(0, "DashboardFilePath", {
    fg = "#8ec07c",  -- Aqua/cyan from Gruvbox - distinctive for file paths
    -- Add fallback for terminals that don't support true color
    ctermfg = 108    -- Aqua in 256-color terminals
  })
  
  vim.api.nvim_set_hl(0, "DashboardFileTime", {
    fg = "#665c54",  -- Dark gray from Gruvbox - subtle for timestamps
    italic = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 241,   -- Dark gray in 256-color terminals
    cterm = { italic = true }
  })

  -- PR highlighting groups
  vim.api.nvim_set_hl(0, "DashboardPRNumber", {
    fg = "#d3869b",  -- Purple from Gruvbox - distinctive for PR numbers
    bold = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 175,   -- Purple in 256-color terminals
    cterm = { bold = true }
  })
  
  vim.api.nvim_set_hl(0, "DashboardPRTitle", {
    fg = "#b8bb26",  -- Bright green from Gruvbox - prominent for PR titles
    -- Add fallback for terminals that don't support true color
    ctermfg = 142    -- Green in 256-color terminals
  })
  
  vim.api.nvim_set_hl(0, "DashboardPRAuthor", {
    fg = "#83a598",  -- Soft blue from Gruvbox - for author names
    -- Add fallback for terminals that don't support true color
    ctermfg = 109    -- Soft blue in 256-color terminals
  })
  
  vim.api.nvim_set_hl(0, "DashboardPRTime", {
    fg = "#665c54",  -- Dark gray from Gruvbox - subtle for timestamps
    italic = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 241,   -- Dark gray in 256-color terminals
    cterm = { italic = true }
  })
  
  -- Hotspot/Most Changed Files highlighting groups
  vim.api.nvim_set_hl(0, "DashboardHotspotCount", {
    fg = "#d3869b",  -- Soft purple from Gruvbox - gentler than bright red
    bold = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 175,   -- Purple in 256-color terminals
    cterm = { bold = true }
  })
  
  vim.api.nvim_set_hl(0, "DashboardHotspotPath", {
    fg = "#fabd2f",  -- Soft yellow/gold from Gruvbox - warm but not harsh
    -- Add fallback for terminals that don't support true color
    ctermfg = 214    -- Yellow/gold in 256-color terminals
  })

  -- Diagnostic highlighting groups
  vim.api.nvim_set_hl(0, "DashboardDiagnosticError", {
    fg = "#fb4934",  -- Red from Gruvbox - for errors
    bold = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 167,   -- Red in 256-color terminals
    cterm = { bold = true }
  })
  
  vim.api.nvim_set_hl(0, "DashboardDiagnosticWarn", {
    fg = "#fabd2f",  -- Yellow from Gruvbox - for warnings
    bold = true,
    -- Add fallback for terminals that don't support true color
    ctermfg = 214,   -- Yellow in 256-color terminals
    cterm = { bold = true }
  })
  
  vim.api.nvim_set_hl(0, "DashboardDiagnosticInfo", {
    fg = "#83a598",  -- Blue from Gruvbox - for info
    -- Add fallback for terminals that don't support true color
    ctermfg = 109    -- Blue in 256-color terminals
  })
  
  vim.api.nvim_set_hl(0, "DashboardDiagnosticHint", {
    fg = "#8ec07c",  -- Cyan from Gruvbox - for hints
    -- Add fallback for terminals that don't support true color
    ctermfg = 108    -- Cyan in 256-color terminals
  })
end

-- Setup autocmd to re-apply highlights when colorscheme changes
local function setup_highlight_autocmd()
  vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
      -- Re-apply our custom highlight groups after colorscheme changes
      setup_highlight_groups()
    end,
    desc = "Re-apply dashboard highlight groups after colorscheme changes"
  })
end

-- Function to get diagnostic information for a file
local function get_file_diagnostics(filepath)
  if not config.show_diagnostics or not filepath then
    return nil
  end

  -- Convert relative path to absolute if needed
  if not vim.startswith(filepath, "/") then
    local repo_root = get_repo_root()
    filepath = repo_root .. "/" .. filepath
  end

  -- Check if file exists
  if vim.fn.filereadable(filepath) ~= 1 then
    return nil
  end

  -- Get the buffer number for this file (if it's loaded)
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr == -1 then
    -- File is not loaded, try to get diagnostics from LSP cache
    -- This might not work for all LSP servers, but worth trying
    local diagnostics = vim.diagnostic.get(nil, { 
      severity = nil,
      namespace = nil
    })
    
    -- Filter diagnostics for this specific file
    local file_diagnostics = {}
    for _, diag in ipairs(diagnostics) do
      local diag_bufnr = diag.bufnr
      if diag_bufnr and vim.api.nvim_buf_is_valid(diag_bufnr) then
        local diag_filepath = vim.api.nvim_buf_get_name(diag_bufnr)
        if diag_filepath == filepath then
          table.insert(file_diagnostics, diag)
        end
      end
    end
    
    if #file_diagnostics == 0 then
      return nil
    end
    
    diagnostics = file_diagnostics
  else
    -- File is loaded, get diagnostics directly
    diagnostics = vim.diagnostic.get(bufnr)
  end

  if not diagnostics or #diagnostics == 0 then
    return nil
  end

  -- Count diagnostics by severity
  local counts = {
    error = 0,
    warn = 0,
    info = 0,
    hint = 0
  }

  for _, diagnostic in ipairs(diagnostics) do
    if diagnostic.severity == vim.diagnostic.severity.ERROR then
      counts.error = counts.error + 1
    elseif diagnostic.severity == vim.diagnostic.severity.WARN then
      counts.warn = counts.warn + 1
    elseif diagnostic.severity == vim.diagnostic.severity.INFO then
      counts.info = counts.info + 1
    elseif diagnostic.severity == vim.diagnostic.severity.HINT then
      counts.hint = counts.hint + 1
    end
  end

  return counts
end

-- Function to format diagnostic counts into a string
local function format_diagnostic_counts(counts)
  if not counts then
    return ""
  end

  local parts = {}
  if counts.error > 0 then
    table.insert(parts, " " .. counts.error)
  end
  if counts.warn > 0 then
    table.insert(parts, " " .. counts.warn)
  end
  if counts.info > 0 then
    table.insert(parts, " " .. counts.info)
  end
  if counts.hint > 0 then
    table.insert(parts, " " .. counts.hint)
  end

  if #parts > 0 then
    return " [" .. table.concat(parts, "") .. "]"
  end
  
  return ""
end

-- Function to add diagnostic segments to a line
local function add_diagnostic_segments(diagnostic_counts)
  if not diagnostic_counts then
    return {}
  end

  local segments = {}
  
  table.insert(segments, { text = " [" })
  
  local first = true
  if diagnostic_counts.error > 0 then
    if not first then table.insert(segments, { text = "" }) end
    table.insert(segments, { text = " " .. diagnostic_counts.error, hl_group = "DashboardDiagnosticError" })
    first = false
  end
  if diagnostic_counts.warn > 0 then
    if not first then table.insert(segments, { text = "" }) end
    table.insert(segments, { text = " " .. diagnostic_counts.warn, hl_group = "DashboardDiagnosticWarn" })
    first = false
  end
  if diagnostic_counts.info > 0 then
    if not first then table.insert(segments, { text = "" }) end
    table.insert(segments, { text = " " .. diagnostic_counts.info, hl_group = "DashboardDiagnosticInfo" })
    first = false
  end
  if diagnostic_counts.hint > 0 then
    if not first then table.insert(segments, { text = "" }) end
    table.insert(segments, { text = " " .. diagnostic_counts.hint, hl_group = "DashboardDiagnosticHint" })
    first = false
  end
  
  table.insert(segments, { text = "]" })
  
  return segments
end

-- Function to apply highlights to all commit elements in the dashboard buffer
local function apply_commit_highlights(buf, lines_data)
  -- Clear any existing highlights in our namespace
  vim.api.nvim_buf_clear_namespace(buf, dashboard_ns, 0, -1)
  
  -- Track which sections we're in by looking for section headers
  local current_line = 0
  local in_commits_section = false
  local in_bookmarks_section = false
  local in_files_section = false
  local in_pr_section = false
  local in_hotspot_section = false
  local passed_commits_separator = false
  local passed_bookmarks_separator = false
  local passed_files_separator = false
  local passed_pr_separator = false
  local passed_hotspot_separator = false
  
  for line_idx, line_data in ipairs(lines_data) do
    local line_text = ""
    for _, segment in ipairs(line_data) do
      line_text = line_text .. segment.text
    end
    
    -- Check if we're entering or leaving sections
    if line_text:match("📝.*Recent Commits") then
      in_commits_section = true
      in_bookmarks_section = false
      in_files_section = false
      in_pr_section = false
      in_hotspot_section = false
      passed_commits_separator = false
      passed_bookmarks_separator = false
      passed_files_separator = false
      passed_pr_separator = false
      passed_hotspot_separator = false
    elseif line_text:match("🔖.*Bookmarks") then
      in_bookmarks_section = true
      in_commits_section = false
      in_files_section = false
      in_pr_section = false
      in_hotspot_section = false
      passed_commits_separator = false
      passed_bookmarks_separator = false
      passed_files_separator = false
      passed_pr_separator = false
      passed_hotspot_separator = false
    elseif line_text:match("📄.*Recent Files") then
      in_files_section = true
      in_commits_section = false
      in_bookmarks_section = false
      in_pr_section = false
      in_hotspot_section = false
      passed_commits_separator = false
      passed_bookmarks_separator = false
      passed_files_separator = false
      passed_pr_separator = false
      passed_hotspot_separator = false
    elseif line_text:match("🚀.*My Open PRs") or line_text:match("👤.*PRs Assigned to Me") or line_text:match("🆕.*Recently Created PRs") or line_text:match("🔄.*Recently Updated PRs") or line_text:match("🔀.*Recent PRs") then
      in_pr_section = true
      in_commits_section = false
      in_bookmarks_section = false
      in_files_section = false
      in_hotspot_section = false
      passed_commits_separator = false
      passed_bookmarks_separator = false
      passed_files_separator = false
      passed_pr_separator = false
      passed_hotspot_separator = false
    elseif line_text:match("🔥.*Most Changed Files") then
      in_hotspot_section = true
      in_commits_section = false
      in_bookmarks_section = false
      in_files_section = false
      in_pr_section = false
      passed_commits_separator = false
      passed_bookmarks_separator = false
      passed_files_separator = false
      passed_pr_separator = false
      passed_hotspot_separator = false
    elseif in_commits_section and line_text:match("^├") then
      -- This is the separator line after the title in the commits section
      passed_commits_separator = true
    elseif in_bookmarks_section and line_text:match("^├") then
      -- This is the separator line after the title in the bookmarks section
      passed_bookmarks_separator = true
    elseif in_files_section and line_text:match("^├") then
      -- This is the separator line after the title in the files section
      passed_files_separator = true
    elseif in_pr_section and line_text:match("^├") then
      -- This is the separator line after the title in the PR section
      passed_pr_separator = true
    elseif in_hotspot_section and line_text:match("^├") then
      -- This is the separator line after the title in the hotspot section
      passed_hotspot_separator = true
    elseif line_text:match("^╭") and not line_text:match("📝.*Recent Commits") and not line_text:match("🔖.*Bookmarks") and not line_text:match("📄.*Recent Files") and not line_text:match("🚀.*My Open PRs") and not line_text:match("👤.*PRs Assigned to Me") and not line_text:match("🆕.*Recently Created PRs") and not line_text:match("🔄.*Recently Updated PRs") and not line_text:match("🔀.*Recent PRs") and not line_text:match("🔥.*Most Changed Files") then
      -- Starting a new section that's not commits, bookmarks, files, PRs, or hotspots
      in_commits_section = false
      in_bookmarks_section = false
      in_files_section = false
      in_pr_section = false
      in_hotspot_section = false
      passed_commits_separator = false
      passed_bookmarks_separator = false
      passed_files_separator = false
      passed_pr_separator = false
      passed_hotspot_separator = false
    elseif line_text:match("^╰") then
      -- End of any section
      in_commits_section = false
      in_bookmarks_section = false
      in_files_section = false
      in_pr_section = false
      in_hotspot_section = false
      passed_commits_separator = false
      passed_bookmarks_separator = false
      passed_files_separator = false
      passed_pr_separator = false
      passed_hotspot_separator = false
    end
    
    -- Now apply highlights based on segments with hl_group
    local byte_offset = 0
    for _, segment in ipairs(line_data) do
      if segment.hl_group then
        local start_byte = byte_offset
        local end_byte = byte_offset + #segment.text
        vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, start_byte, {
          end_col = end_byte,
          hl_group = segment.hl_group
        })
      end
      byte_offset = byte_offset + #segment.text
    end
    
    -- Only highlight commit elements if we're in the commits section AND past the separator
    if in_commits_section and passed_commits_separator and line_text:match("^│") then
      -- This is a content line within a box (starts with │)
      -- Extract the content between the box characters
      local content = line_text:match("^│ (.*) │$")
      if content then
        -- Trim leading/trailing whitespace
        content = content:gsub("^%s+", ""):gsub("%s+$", "")
        
        -- Check if this looks like a commit line (starts with a hash)
        local commit_hash = content:match("^([a-f0-9]+)%s+")
        if commit_hash and #commit_hash >= 4 then  -- At least 4 characters for a valid hash
          -- Parse the commit line: "hash message (author, time ago)"
          local message_part = content:match("^[a-f0-9]+%s+(.*)%s+%(.*%)")
          local meta_part = content:match("%((.+)%)")
          
          -- Calculate byte positions for different parts
          local box_char_bytes = 3  -- │ character in UTF-8
          local space_bytes = 1     -- space character
          
          -- 1. Highlight commit hash
          local hash_start_byte = box_char_bytes + space_bytes
          local hash_end_byte = hash_start_byte + #commit_hash
          vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, hash_start_byte, {
            end_col = hash_end_byte,
            hl_group = "DashboardCommitHash"
          })
          
          -- 2. Highlight commit message
          if message_part then
            local message_start_byte = hash_end_byte + 1  -- +1 for space after hash
            local message_end_byte = message_start_byte + #message_part
            vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, message_start_byte, {
              end_col = message_end_byte,
              hl_group = "DashboardCommitMessage"
            })
          end
          
          -- 3. Highlight metadata (author, time ago) - everything in parentheses
          if meta_part then
            -- Find the opening parenthesis position
            local paren_start_pos = content:find("%(")
            if paren_start_pos then
              local meta_start_byte = box_char_bytes + space_bytes + paren_start_pos - 1
              local meta_end_byte = meta_start_byte + #meta_part + 2  -- +2 for the parentheses
              vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, meta_start_byte, {
                end_col = meta_end_byte,
                hl_group = "DashboardCommitMeta"
              })
            end
          end
        end
      end
    end
    
    -- Only highlight bookmark elements if we're in the bookmarks section AND past the separator
    if in_bookmarks_section and passed_bookmarks_separator and line_text:match("^│") then
      -- This is a content line within a box (starts with │)
      -- Extract the content between the box characters
      local content = line_text:match("^│ (.*) │$")
      if content then
        -- Trim leading/trailing whitespace
        content = content:gsub("^%s+", ""):gsub("%s+$", "")
        
        -- Check if this looks like a bookmark line: "[1] name (path/to/file:123)"
        local bookmark_number = content:match("^%[(%d+)%]")
        if bookmark_number then
          -- Parse the bookmark line
          local name_part = content:match("^%[%d+%]%s+([^%(]+)")
          local path_part = content:match("%(([^:]+)")
          local line_part = content:match(":(%d+)%)")
          
          -- Calculate byte positions
          local box_char_bytes = 3  -- │ character in UTF-8
          local space_bytes = 1     -- space character
          
          -- 1. Highlight bookmark number [1]
          local number_start_byte = box_char_bytes + space_bytes
          local number_end_byte = number_start_byte + #("[" .. bookmark_number .. "]")
          vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, number_start_byte, {
            end_col = number_end_byte,
            hl_group = "DashboardBookmarkNumber"
          })
          
          -- 2. Highlight bookmark name
          if name_part then
            name_part = name_part:gsub("%s+$", "") -- trim trailing spaces
            local name_start_byte = number_end_byte + 1  -- +1 for space after ]
            local name_end_byte = name_start_byte + #name_part
            vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, name_start_byte, {
              end_col = name_end_byte,
              hl_group = "DashboardBookmarkName"
            })
          end
          
          -- 3. Highlight file path
          if path_part then
            local paren_start_pos = content:find("%(")
            if paren_start_pos then
              local path_start_byte = box_char_bytes + space_bytes + paren_start_pos  -- +1 for opening paren
              local path_end_byte = path_start_byte + #path_part
              vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, path_start_byte, {
                end_col = path_end_byte,
                hl_group = "DashboardBookmarkPath"
              })
            end
          end
          
          -- 4. Highlight line number
          if line_part then
            local colon_pos = content:find(":[^:]*$") -- find the last colon
            if colon_pos then
              local line_start_byte = box_char_bytes + space_bytes + colon_pos  -- +1 for colon
              local line_end_byte = line_start_byte + #line_part
              vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, line_start_byte, {
                end_col = line_end_byte,
                hl_group = "DashboardBookmarkLine"
              })
            end
          end
        end
      end
    end
    
    -- Only highlight recent files elements if we're in the files section AND past the separator
    if in_files_section and passed_files_separator and line_text:match("^│") then
      -- This is a content line within a box (starts with │)
      -- Extract the content between the box characters
      local content = line_text:match("^│ (.*) │$")
      if content then
        -- Trim leading/trailing whitespace
        content = content:gsub("^%s+", ""):gsub("%s+$", "")
        
        -- Check if this looks like a recent file line: "path/to/file (time ago)"
        local time_part = content:match("(%([^%)]+%))")
        if time_part then
          -- Parse the file line
          local file_part = content:match("^(.-)%s+%([^%)]+%)$")
          
          -- Calculate byte positions
          local box_char_bytes = 3  -- │ character in UTF-8
          local space_bytes = 1     -- space character
          
          -- 1. Highlight file path
          if file_part then
            file_part = file_part:gsub("%s+$", "") -- trim trailing spaces
            local file_start_byte = box_char_bytes + space_bytes
            local file_end_byte = file_start_byte + #file_part
            vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, file_start_byte, {
              end_col = file_end_byte,
              hl_group = "DashboardFilePath"
            })
          end
          
          -- 2. Highlight timestamp (time ago)
          local paren_start_pos = content:find("%(")
          if paren_start_pos then
            local time_start_byte = box_char_bytes + space_bytes + paren_start_pos - 1
            local time_end_byte = time_start_byte + #time_part
            vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, time_start_byte, {
              end_col = time_end_byte,
              hl_group = "DashboardFileTime"
            })
          end
        end
      end
    end
    
    -- Only highlight PR elements if we're in a PR section AND past the separator
    if in_pr_section and passed_pr_separator and line_text:match("^│") then
      -- This is a content line within a box (starts with │)
      -- Extract the content between the box characters
      local original_content = line_text:match("^│ (.*) │$")
      if original_content then
        -- Trim leading/trailing whitespace for pattern matching
        local content = original_content:gsub("^%s+", ""):gsub("%s+$", "")
        
        -- Check if this looks like a PR title line: "#123 🟢 Title of PR"
        local pr_number = content:match("^#(%d+)%s+")
        if pr_number then
          -- Only highlight the PR number (#123)
          local box_char_bytes = 3  -- │ character in UTF-8
          local space_bytes = 1     -- space character
          
          local pr_number_text = "#" .. pr_number
          local pr_number_start_byte = box_char_bytes + space_bytes
          local pr_number_end_byte = pr_number_start_byte + #pr_number_text
          vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, pr_number_start_byte, {
            end_col = pr_number_end_byte,
            hl_group = "DashboardPRNumber"
          })
        else
          -- Check if this is an author/time line: "  by author, time ago"
          if content:match("^%s*by%s+") then
            -- Highlight the entire author/time line with subtle color
            local box_char_bytes = 3  -- │ character in UTF-8
            local space_bytes = 1     -- space character
            
            -- Use original_content (untrimmed) for byte position calculation
            local content_start_byte = box_char_bytes + space_bytes
            local content_end_byte = content_start_byte + #original_content
            vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, content_start_byte, {
              end_col = content_end_byte,
              hl_group = "DashboardPRTime"
            })
          end
        end
      end
    end
    
    -- Only highlight hotspot elements if we're in the hotspot section AND past the separator
    if in_hotspot_section and passed_hotspot_separator and line_text:match("^│") then
      -- This is a content line within a box (starts with │)
      -- Extract the content between the box characters
      local original_content = line_text:match("^│ (.*) │$")
      if original_content then
        -- Trim leading/trailing whitespace for pattern matching
        local content = original_content:gsub("^%s+", ""):gsub("%s+$", "")
        
        -- Check if this looks like a hotspot line: "[5×] path/to/file"
        local change_count = content:match("^%[(%d+)×%]")
        if change_count then
          -- Parse the hotspot line
          local path_part = content:match("^%[%d+×%]%s+(.+)$")
          
          -- Calculate byte positions
          local box_char_bytes = 3  -- │ character in UTF-8
          local space_bytes = 1     -- space character
          
          -- 1. Highlight change count [5×]
          local count_text = "[" .. change_count .. "×]"
          local count_start_byte = box_char_bytes + space_bytes
          local count_end_byte = count_start_byte + #count_text
          vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, count_start_byte, {
            end_col = count_end_byte,
            hl_group = "DashboardHotspotCount"
          })
          
          -- 2. Highlight file path
          if path_part then
            local path_start_byte = count_end_byte + 1  -- +1 for space after ]
            local path_end_byte = path_start_byte + #path_part
            vim.api.nvim_buf_set_extmark(buf, dashboard_ns, current_line, path_start_byte, {
              end_col = path_end_byte,
              hl_group = "DashboardHotspotPath"
            })
          end
        end
      end
    end
    
    current_line = current_line + 1
  end
end

-- Utility functions
local function get_repo_root()
  local current_dir = vim.fn.getcwd()
  local git_root = vim.fn.systemlist("cd " .. vim.fn.shellescape(current_dir) .. " && git rev-parse --show-toplevel 2>/dev/null")[1]
  if git_root and git_root ~= "" then
    return git_root
  end
  return current_dir
end

local function get_repo_name()
  local repo_root = get_repo_root()
  return vim.fn.fnamemodify(repo_root, ":t")
end

local function is_git_repo()
  local git_dir = vim.fn.systemlist("git rev-parse --git-dir 2>/dev/null")[1]
  return git_dir and git_dir ~= ""
end

local function format_relative_path(filepath)
  local repo_root = get_repo_root()
  local relative = vim.fn.fnamemodify(filepath, ":~")
  -- If the file is within the repo, show relative to repo root
  if vim.startswith(filepath, repo_root) then
    -- Calculate relative path from repo root
    local absolute_path = vim.fn.fnamemodify(filepath, ":p")
    relative = absolute_path:sub(#repo_root + 2) -- +2 to skip the trailing slash
  end
  return relative
end

local function format_time_ago(timestamp)
  local now = os.time()
  local diff = now - timestamp
  
  if diff < 60 then
    local seconds = math.floor(diff)
    if seconds < 0 then
      return "just now"
    elseif seconds == 1 then
      return "1 second ago"
    else
      return seconds .. " seconds ago"
    end
  elseif diff < 3600 then
    local minutes = math.floor(diff / 60)
    if minutes == 1 then
      return "1 minute ago"
    else
      return minutes .. " minutes ago"
    end
  elseif diff < 86400 then
    local hours = math.floor(diff / 3600)
    if hours == 1 then
      return "1 hour ago"
    else
      return hours .. " hours ago"
    end
  elseif diff < 2592000 then
    local days = math.floor(diff / 86400)
    if days == 1 then
      return "1 day ago"
    else
      return days .. " days ago"
    end
  else
    return os.date("%Y-%m-%d", timestamp)
  end
end

-- Helper function to parse GitHub ISO 8601 timestamps to UTC epoch
local function parse_github_timestamp(iso_string)
  if not iso_string then return os.time() end
  
  -- Parse ISO 8601 format: 2023-12-01T10:30:45Z
  local year, month, day, hour, min, sec = iso_string:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  
  if not year then return os.time() end
  
  -- GitHub timestamps are in UTC (indicated by Z suffix)
  -- We need to convert this UTC time to local time for comparison
  
  -- Create UTC timestamp using a more reliable method
  -- This works by creating a time as if it were local, then adjusting for timezone
  local utc_table = {
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  }
  
  -- Get current timezone offset in seconds
  local now = os.time()
  local utc_now = os.time(os.date("!*t", now))
  local tz_offset = os.difftime(now, utc_now)
  
  -- Create the timestamp as if the UTC time were local, then apply timezone correction
  local utc_as_local = os.time(utc_table)
  -- Convert to actual local time by adding the timezone offset
  return utc_as_local + tz_offset
end

-- Data collection functions
local function get_git_commits()
  if not is_git_repo() then return {} end
  
  local cmd = string.format(
    'git log --oneline --max-count=%d --pretty=format:"%%h|%%s|%%an|%%at"',
    config.git_max_commits
  )
  
  local output = vim.fn.systemlist(cmd)
  local commits = {}
  
  for _, line in ipairs(output) do
    local hash, message, author, timestamp = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
    if hash then
      table.insert(commits, {
        hash = hash,
        message = message,
        author = author,
        timestamp = tonumber(timestamp),
        time_ago = format_time_ago(tonumber(timestamp))
      })
    end
  end
  
  return commits
end

local function get_git_status()
  if not is_git_repo() then return nil end
  
  local branch = vim.fn.systemlist("git branch --show-current 2>/dev/null")[1] or "unknown"
  local status = vim.fn.systemlist("git status --porcelain 2>/dev/null")
  
  local stats = {
    modified = 0,
    added = 0,
    deleted = 0,
    untracked = 0
  }
  
  for _, line in ipairs(status) do
    local status_code = line:sub(1, 2)
    if status_code:match("^M") or status_code:match("^.M") then
      stats.modified = stats.modified + 1
    elseif status_code:match("^A") or status_code:match("^.A") then
      stats.added = stats.added + 1
    elseif status_code:match("^D") or status_code:match("^.D") then
      stats.deleted = stats.deleted + 1
    elseif status_code:match("^%?%?") then
      stats.untracked = stats.untracked + 1
    end
  end
  
  return {
    branch = branch,
    stats = stats
  }
end

local function get_branch_info()
  if not is_git_repo() then return nil end
  
  local branch = vim.fn.systemlist("git branch --show-current 2>/dev/null")[1]
  if not branch or branch == "" then return nil end
  
  -- Get upstream branch
  local upstream = vim.fn.systemlist("git rev-parse --abbrev-ref @{upstream} 2>/dev/null")[1]
  if not upstream or upstream == "" then
    return {
      branch = branch,
      upstream = nil,
      ahead = 0,
      behind = 0
    }
  end
  
  -- Get ahead/behind counts
  local ahead_behind = vim.fn.systemlist("git rev-list --left-right --count " .. upstream .. "..." .. branch .. " 2>/dev/null")[1]
  local behind, ahead = 0, 0
  
  if ahead_behind and ahead_behind ~= "" then
    behind, ahead = ahead_behind:match("(%d+)%s+(%d+)")
    ahead = tonumber(ahead) or 0
    behind = tonumber(behind) or 0
  end
  
  return {
    branch = branch,
    upstream = upstream,
    ahead = ahead,
    behind = behind
  }
end

local function get_git_hotspots()
  if not is_git_repo() then return {} end
  
  -- Get file change frequency from git log
  local cmd = string.format(
    'git log --name-only --pretty=format: --since="3 months ago" | grep -v "^$" | sort | uniq -c | sort -rn | head -%d',
    config.max_hotspot_files
  )
  
  local output = vim.fn.systemlist(cmd .. " 2>/dev/null")
  local hotspots = {}
  local repo_root = get_repo_root()
  
  for _, line in ipairs(output) do
    local count, file = line:match("^%s*(%d+)%s+(.+)$")
    if count and file then
      -- Convert relative path to absolute path for file readability check
      local absolute_file = repo_root .. "/" .. file
      if vim.fn.filereadable(absolute_file) == 1 then
        local diagnostics = get_file_diagnostics(absolute_file)
        table.insert(hotspots, {
          file = absolute_file,
          count = tonumber(count),
          relative_path = file,  -- Use the git-relative path directly
          diagnostics = diagnostics
        })
      end
    end
  end
  
  return hotspots
end

local function get_recent_prs()
  if not is_git_repo() then return {}, {}, {}, {} end
  
  local created_prs = {}
  local updated_prs = {}
  local my_created_prs = {}
  local my_assigned_prs = {}
  
  -- Check if we can get GitHub repo info
  local remote_url = vim.fn.systemlist("git remote get-url origin 2>/dev/null")[1]
  if not remote_url or remote_url == "" then
    return created_prs, updated_prs, my_created_prs, my_assigned_prs
  end
  
  -- Extract owner/repo from remote URL
  local owner, repo
  if remote_url:match("github%.com") then
    -- Handle both SSH and HTTPS URLs
    if remote_url:match("^git@") then
      -- SSH: git@github.com:owner/repo.git
      owner, repo = remote_url:match("git@github%.com:([^/]+)/(.+)%.git")
    else
      -- HTTPS: https://github.com/owner/repo.git
      owner, repo = remote_url:match("github%.com/([^/]+)/(.+)%.git")
    end
    
    if not repo then
      -- Try without .git suffix
      if remote_url:match("^git@") then
        owner, repo = remote_url:match("git@github%.com:([^/]+)/(.+)$")
      else
        owner, repo = remote_url:match("github%.com/([^/]+)/(.+)$")
      end
    end
  end
  
  if not owner or not repo then
    return created_prs, updated_prs, my_created_prs, my_assigned_prs
  end
  
  -- Use GitHub CLI if available for better rate limits and auth
  local gh_available = vim.fn.executable("gh") == 1
  if gh_available then
    -- Get current user
    local current_user = vim.fn.system("gh api user --jq .login 2>/dev/null"):gsub('\n', '')
    if vim.v.shell_error ~= 0 or current_user == "" then
      current_user = nil
    end
    
    -- Get recent PRs with both created and updated timestamps
    local limit = math.max(config.max_recent_prs_created or 5, config.max_recent_prs_updated or 5) * 2
    local cmd = string.format(
      'gh pr list --repo %s/%s --limit %d --state all --json number,title,author,createdAt,updatedAt,state,url,assignees',
      owner, repo, limit
    )
    
    local output = vim.fn.system(cmd .. " 2>/dev/null")
    if vim.v.shell_error == 0 and output ~= "" then
      local ok, pr_data = pcall(vim.json.decode, output)
      if ok and pr_data then
        local all_prs = {}
        for _, pr in ipairs(pr_data) do
          local created_time = pr.createdAt and parse_github_timestamp(pr.createdAt) or os.time()
          local updated_time = pr.updatedAt and parse_github_timestamp(pr.updatedAt) or os.time()
          
          table.insert(all_prs, {
            number = pr.number,
            title = pr.title,
            author = pr.author and pr.author.login or "unknown",
            state = pr.state,
            created_at = created_time,
            updated_at = updated_time,
            url = pr.url,
            assignees = pr.assignees or {}
          })
        end
        
        -- Sort by creation time and take the most recent created PRs
        local sorted_by_created = vim.deepcopy(all_prs)
        table.sort(sorted_by_created, function(a, b) return a.created_at > b.created_at end)
        for i = 1, math.min(config.max_recent_prs_created or 5, #sorted_by_created) do
          local pr = sorted_by_created[i]
          table.insert(created_prs, {
            number = pr.number,
            title = pr.title,
            author = pr.author,
            state = pr.state,
            created_at = pr.created_at,
            time_ago = format_time_ago(pr.created_at),
            url = pr.url
          })
        end
        
        -- Sort by update time and take the most recent updated PRs
        local sorted_by_updated = vim.deepcopy(all_prs)
        table.sort(sorted_by_updated, function(a, b) return a.updated_at > b.updated_at end)
        for i = 1, math.min(config.max_recent_prs_updated or 5, #sorted_by_updated) do
          local pr = sorted_by_updated[i]
          table.insert(updated_prs, {
            number = pr.number,
            title = pr.title,
            author = pr.author,
            state = pr.state,
            updated_at = pr.updated_at,
            time_ago = format_time_ago(pr.updated_at),
            url = pr.url
          })
        end
        
        -- Get PRs created by current user (open only)
        if current_user then
          local my_created_open = {}
          for _, pr in ipairs(all_prs) do
            if pr.author == current_user and pr.state == "OPEN" then
              table.insert(my_created_open, pr)
            end
          end
          
          -- Sort by update time (most recent first)
          table.sort(my_created_open, function(a, b) return a.updated_at > b.updated_at end)
          for i = 1, math.min(5, #my_created_open) do
            local pr = my_created_open[i]
            table.insert(my_created_prs, {
              number = pr.number,
              title = pr.title,
              author = pr.author,
              state = pr.state,
              created_at = pr.created_at,
              updated_at = pr.updated_at,
              time_ago = format_time_ago(pr.updated_at),
              url = pr.url
            })
          end
          
          -- Get PRs assigned to current user (open only)
          local my_assigned_open = {}
          for _, pr in ipairs(all_prs) do
            if pr.state == "OPEN" and pr.assignees then
              for _, assignee in ipairs(pr.assignees) do
                if assignee.login == current_user then
                  table.insert(my_assigned_open, pr)
                  break
                end
              end
            end
          end
          
          -- Sort by creation time (most recent first)
          table.sort(my_assigned_open, function(a, b) return a.created_at > b.created_at end)
          for i = 1, math.min(5, #my_assigned_open) do
            local pr = my_assigned_open[i]
            table.insert(my_assigned_prs, {
              number = pr.number,
              title = pr.title,
              author = pr.author,
              state = pr.state,
              created_at = pr.created_at,
              time_ago = format_time_ago(pr.created_at),
              url = pr.url
            })
          end
        end
      end
    end
  else
    -- Fallback: try to use git log to find PR merge commits
    local cmd = 'git log --oneline --grep="Merge pull request" --since="1 month ago" --max-count=10'
    local output = vim.fn.systemlist(cmd .. " 2>/dev/null")
    
    for _, line in ipairs(output) do
      local hash, message = line:match("^([a-f0-9]+)%s+(.+)$")
      if hash and message:match("Merge pull request") then
        local pr_number = message:match("#(%d+)")
        if pr_number then
          -- Get commit timestamp
          local timestamp_cmd = 'git show -s --format=%at ' .. hash
          local timestamp = vim.fn.system(timestamp_cmd .. " 2>/dev/null"):gsub('\n', '')
          local commit_time = tonumber(timestamp) or os.time()
          
          local pr_entry = {
            number = tonumber(pr_number),
            title = message:gsub("Merge pull request #%d+ from [^:]+:", ""):gsub("^%s+", ""),
            author = "merged",
            state = "merged",
            created_at = commit_time,
            updated_at = commit_time,
            time_ago = format_time_ago(commit_time),
            url = string.format("https://github.com/%s/%s/pull/%s", owner, repo, pr_number)
          }
          
          -- Add to both lists since we can't distinguish create vs update times from git log
          if #created_prs < (config.max_recent_prs_created or 5) then
            table.insert(created_prs, pr_entry)
          end
          if #updated_prs < (config.max_recent_prs_updated or 5) then
            table.insert(updated_prs, pr_entry)
          end
        end
      end
    end
  end
  
  return created_prs, updated_prs, my_created_prs, my_assigned_prs
end

local function get_recent_files()
  local recent_files = {}
  
  -- Create repo-specific data file path
  local repo_root = get_repo_root()
  local safe_name = repo_root:gsub("[/\\:*?\"<>|]", "_"):gsub("__+", "_"):gsub("^_+", ""):gsub("_+$", "") .. "_recent_files.json"
  local data_file = vim.fn.stdpath("data") .. "/dashboard/" .. safe_name
  
  -- Read existing data
  local file = io.open(data_file, "r")
  if file then
    local content = file:read("*a")
    file:close()
    
    local ok, data = pcall(vim.json.decode, content)
    if ok and data and data.files then
      -- Sort by timestamp (most recent first) and take only 5
      table.sort(data.files, function(a, b) return a.timestamp > b.timestamp end)
      
      for i = 1, math.min(5, #data.files) do
        local file_data = data.files[i]
        if vim.fn.filereadable(file_data.path) == 1 then
          local diagnostics = get_file_diagnostics(file_data.path)
          table.insert(recent_files, {
            path = file_data.path,
            relative_path = format_relative_path(file_data.path),
            access_time = file_data.timestamp,
            time_ago = format_time_ago(file_data.timestamp),
            diagnostics = diagnostics
          })
        end
      end
    end
  end
  
  return recent_files
end

local function is_gitignored(filepath)
  if not filepath or not is_git_repo() then return false end
  
  -- Use git check-ignore to see if file is ignored
  local cmd = "git check-ignore " .. vim.fn.shellescape(filepath) .. " 2>/dev/null"
  local result = vim.fn.system(cmd)
  
  -- git check-ignore returns 0 if file is ignored, 1 if not ignored
  return vim.v.shell_error == 0
end

local function track_visited_file(filepath)
  if not filepath or filepath == "" then return end
  
  -- Don't track gitignored files
  if is_gitignored(filepath) then return end
  
  -- Don't track certain file types
  local exclude_patterns = {
    "^/tmp/",
    "%.git/",
    "dashboard$",
    "COMMIT_EDITMSG$",
    "MERGE_MSG$",
    "SQUASH_MSG$",
    "%.tmp$",
    "%.swp$",
    "%.gitignore$",
    "%.gitmodules$",
    "%.gitattributes$",
    "/%.git$",
    "git%-rebase%-todo$",
    "git%-rebase%-todo%.backup$",
    "fugitive:",
    "%.orig$"
  }
  
  for _, pattern in ipairs(exclude_patterns) do
    if filepath:match(pattern) then return end
  end
  
  -- Create repo-specific data file path
  local repo_root = get_repo_root()
  local safe_name = repo_root:gsub("[/\\:*?\"<>|]", "_"):gsub("__+", "_"):gsub("^_+", ""):gsub("_+$", "") .. "_recent_files.json"
  local data_dir = vim.fn.stdpath("data") .. "/dashboard"
  local data_file = data_dir .. "/" .. safe_name
  
  -- Ensure data directory exists
  vim.fn.mkdir(data_dir, "p")
  
  local current_time = os.time()
  
  -- Read existing data
  local data = { files = {} }
  local file = io.open(data_file, "r")
  if file then
    local content = file:read("*a")
    file:close()
    
    local ok, existing_data = pcall(vim.json.decode, content)
    if ok and existing_data and existing_data.files then
      data = existing_data
    end
  end
  
  -- Remove existing entry for this file if it exists
  for i = #data.files, 1, -1 do
    if data.files[i].path == filepath then
      table.remove(data.files, i)
    end
  end
  
  -- Add current file to the beginning
  table.insert(data.files, 1, {
    path = filepath,
    timestamp = current_time
  })
  
  -- Keep only the most recent 20 files to prevent file from growing too large
  while #data.files > 20 do
    table.remove(data.files)
  end
  
  -- Write back to file
  local file_write = io.open(data_file, "w")
  if file_write then
    file_write:write(vim.json.encode(data))
    file_write:close()
  end
end

local function get_current_bookmarks()
  local ok, bookmark_sets = pcall(require, 'myplugins.bookmark-sets')
  if not ok then return {} end
  
  -- We need to access internal functions - this is a bit hacky but necessary
  local repo_root = get_repo_root()
  
  -- Try to load bookmark data (mimicking bookmark-sets internal logic)
  local data_dir = vim.fn.stdpath("data") .. "/bookmark-sets"
  local safe_name = repo_root:gsub("[/\\:*?\"<>|]", "_"):gsub("__+", "_"):gsub("^_+", ""):gsub("_+$", "") .. ".json"
  local data_file = data_dir .. "/" .. safe_name
  
  local bookmarks = {}
  local file = io.open(data_file, "r")
  if file then
    local content = file:read("*a")
    file:close()
    
    local ok_decode, data = pcall(vim.json.decode, content)
    if ok_decode and data and data.sets and data.current_set then
      local current_set = data.sets[data.current_set]
      if current_set and current_set.bookmarks then
        for i, bookmark in ipairs(current_set.bookmarks) do
          if i > config.max_bookmarks then break end
          if vim.fn.filereadable(bookmark.file) == 1 then
            local diagnostics = get_file_diagnostics(bookmark.file)
            table.insert(bookmarks, {
              file = bookmark.file,
              line = bookmark.line,
              nickname = bookmark.nickname,
              relative_path = format_relative_path(bookmark.file),
              set_name = data.current_set,
              diagnostics = diagnostics
            })
          end
        end
      end
    end
  end
  
  return bookmarks
end

-- UI functions
local function create_dashboard_content()
  local lines_data = {} -- Changed from lines to lines_data
  local repo_name = get_repo_name()
  local git_status = get_git_status()
  local branch_info = get_branch_info()
  
  -- Get all data
  local commits = is_git_repo() and get_git_commits() or {}
  local hotspots = is_git_repo() and get_git_hotspots() or {}
  local bookmarks = get_current_bookmarks()
  local recent_files = get_recent_files()
  local created_prs, updated_prs, my_created_prs, my_assigned_prs = get_recent_prs()
  
  -- Helper to add a line with segments
  local function add_line(segments_for_this_line_TABLE) -- Changed signature and implementation
    table.insert(lines_data, segments_for_this_line_TABLE)
  end

  -- Header section
  add_line({ { text = "" } }) -- Changed: Wrapped in an extra table to be a list of segments
  add_line({ { text = "📁 " }, { text = repo_name } })
  
  if branch_info then
    local branch_segments = { { text = "🌿 " }, { text = branch_info.branch } }
    
    if branch_info.upstream then
      local upstream_short = branch_info.upstream:gsub("^origin/", "")
      table.insert(branch_segments, { text = " → " })
      table.insert(branch_segments, { text = upstream_short })
      
      if branch_info.ahead > 0 or branch_info.behind > 0 then
        local sync_info_text = " (" 
        local sync_parts = {}
        if branch_info.ahead > 0 then
          table.insert(sync_parts, "↑" .. branch_info.ahead)
        end
        if branch_info.behind > 0 then
          table.insert(sync_parts, "↓" .. branch_info.behind)
        end
        sync_info_text = sync_info_text .. table.concat(sync_parts, " ") .. ")"
        table.insert(branch_segments, { text = sync_info_text })
      else
        table.insert(branch_segments, { text = " (✓)" })
      end
    end
    add_line(branch_segments)
  elseif git_status then
    add_line({ { text = "🌿 " }, { text = git_status.branch } })
  end
  
  -- Git status changes
  if git_status and (git_status.stats.modified + git_status.stats.added + git_status.stats.deleted + git_status.stats.untracked > 0) then
    local status_segments = { { text = "📝 Changes: " } }
    local status_parts_text = {}
    if git_status.stats.modified > 0 then table.insert(status_parts_text, "Modified:" .. git_status.stats.modified) end
    if git_status.stats.added > 0 then table.insert(status_parts_text, "Added:" .. git_status.stats.added) end
    if git_status.stats.deleted > 0 then table.insert(status_parts_text, "Deleted:" .. git_status.stats.deleted) end
    if git_status.stats.untracked > 0 then table.insert(status_parts_text, "Untracked:" .. git_status.stats.untracked) end
    
    table.insert(status_segments, { text = table.concat(status_parts_text, " ") })
    add_line(status_segments)
  end
  
  add_line({ { text = "" } }) -- Changed: Wrapped
  
  -- Helper function to create a boxed section
  local function add_boxed_section(title_icon, title_text, content_lines_data)
    if #content_lines_data == 0 then return end
    
    -- Calculate the maximum width needed for this section
    local max_content_width = 0
    for _, line_data in ipairs(content_lines_data) do
      local current_line_width = 0
      for _, segment in ipairs(line_data) do
        current_line_width = current_line_width + vim.fn.strwidth(segment.text)
      end
      max_content_width = math.max(max_content_width, current_line_width)
    end
    
    local title_width = vim.fn.strwidth(title_icon) + vim.fn.strwidth(title_text)
    local box_inner_width = math.max(max_content_width, title_width)
    local box_width = box_inner_width + 4
    
    -- Top border
    add_line({ { text = "╭" .. string.rep("─", box_width - 2) .. "╮" } })
    
    -- Title
    local title_padding_size = box_inner_width - title_width
    add_line({
      { text = "│ " },
      { text = title_icon }, 
      { text = title_text },
      { text = string.rep(" ", title_padding_size) .. " │" }
    })
    
    -- Separator
    add_line({ { text = "├" .. string.rep("─", box_width - 2) .. "┤" } })
    
    -- Content lines
    for _, line_data in ipairs(content_lines_data) do
      local current_line_text_width = 0
      for _, segment in ipairs(line_data) do
        current_line_text_width = current_line_text_width + vim.fn.strwidth(segment.text)
      end
      local line_padding_size = box_inner_width - current_line_text_width
      
      local assembled_line = { { text = "│ " } }
      for _, segment in ipairs(line_data) do
        table.insert(assembled_line, segment)
      end
      table.insert(assembled_line, { text = string.rep(" ", line_padding_size) .. " │" })
      add_line(assembled_line)
    end
    
    -- Bottom border
    add_line({ { text = "╰" .. string.rep("─", box_width - 2) .. "╯" } })
    add_line({ { text = "" } }) -- Changed: Wrapped
  end
  
  -- Recent Commits section
  if #commits > 0 then
    local commit_lines_data = {}
    for i, commit in ipairs(commits) do
      local commit_message_display = commit.message
      local commit_line_display = commit.hash .. " " .. commit_message_display .. " (" .. commit.time_ago .. ")"
      if vim.fn.strwidth(commit_line_display) > 80 then
         -- Smart truncation: prioritize message, then hash, then time_ago
        local available_width = 80 - vim.fn.strwidth(commit.hash .. "  (...)" .. commit.time_ago) - 3 -- for "..."
        if available_width > 5 then
            commit_message_display = commit_message_display:sub(1, math.floor(vim.fn.strwidth(commit_message_display) * available_width / vim.fn.strwidth(commit_message_display))) .. "..."
        else
            commit_message_display = "..."
        end
      end
      local commit_line_segments = {
        { text = commit.hash },
        { text = " " },
        { text = commit_message_display },
        { text = " (" .. commit.author .. ", " .. commit.time_ago .. ")" }
      }
      table.insert(commit_lines_data, commit_line_segments)
    end
    add_boxed_section("📝 ", "Recent Commits", commit_lines_data)
  end
  
  -- Bookmarks section
  if #bookmarks > 0 then
    local bookmark_lines_data = {}
    for i, bookmark in ipairs(bookmarks) do
      local display_name = bookmark.nickname or vim.fn.fnamemodify(bookmark.file, ":t")
      local line_text = "[" .. i .. "] " .. display_name .. " (" .. bookmark.relative_path .. ":" .. bookmark.line .. ")"
      local line_segments = {}
      table.insert(line_segments, { text = "[" .. i .. "] " })
      table.insert(line_segments, { text = display_name })
      table.insert(line_segments, { text = " (" })
      table.insert(line_segments, { text = bookmark.relative_path })
      table.insert(line_segments, { text = ":" .. bookmark.line })
      table.insert(line_segments, { text = ")" })
      
      -- Add diagnostic information if available
      if bookmark.diagnostics then
        local diagnostic_segments = add_diagnostic_segments(bookmark.diagnostics)
        for _, seg in ipairs(diagnostic_segments) do
          table.insert(line_segments, seg)
        end
      end
      
      -- Truncation logic (simplified for now, can be improved)
      local current_width = 0
      for _, seg in ipairs(line_segments) do current_width = current_width + vim.fn.strwidth(seg.text) end
      if current_width > 80 then
          local truncated_segments = {}
          local available_width = 80 - 3 -- for "..."
          local built_width = 0
          for _, seg in ipairs(line_segments) do
              if built_width + vim.fn.strwidth(seg.text) < available_width then
                  table.insert(truncated_segments, seg)
                  built_width = built_width + vim.fn.strwidth(seg.text)
              else
                  local remaining_len = available_width - built_width
                  if remaining_len > 0 then
                      table.insert(truncated_segments, {text = seg.text:sub(1,remaining_len)})
                  end
                  table.insert(truncated_segments, {text = "..."})
                  break
              end
          end
          line_segments = truncated_segments
      end
      table.insert(bookmark_lines_data, line_segments)
    end
    add_boxed_section("🔖 ", "Bookmarks (" .. bookmarks[1].set_name .. ")", bookmark_lines_data)
  end
  
  -- Recent files section
  if #recent_files > 0 then
    local file_lines_data = {}
    for i, file_info in ipairs(recent_files) do
      local path_text = file_info.relative_path
      local time_text = " (" .. file_info.time_ago .. ")"
      
      local line_segments = {
        { text = path_text },
        { text = time_text }
      }
      
      -- Add diagnostic information if available
      if file_info.diagnostics then
        local diagnostic_segments = add_diagnostic_segments(file_info.diagnostics)
        for _, seg in ipairs(diagnostic_segments) do
          table.insert(line_segments, seg)
        end
      end
      
      local total_width = 0
      for _, seg in ipairs(line_segments) do
        total_width = total_width + vim.fn.strwidth(seg.text)
      end
      
      if total_width > 80 then
        local available_path_width = 80 - vim.fn.strwidth(time_text) - 3 -- for "..."
        -- Account for diagnostic text if present
        if file_info.diagnostics then
          available_path_width = available_path_width - vim.fn.strwidth(format_diagnostic_counts(file_info.diagnostics))
        end
        
        if available_path_width > 5 then
          line_segments[1].text = path_text:sub(1, math.max(1, available_path_width)) .. "..."
        else 
          line_segments[1].text = path_text:sub(1, math.max(1, 80-3)) .. "..." -- fallback if time_text is too long
          line_segments[2].text = ""
          -- Remove diagnostic segments if we're out of space
          for j = #line_segments, 3, -1 do
            line_segments[j] = nil
          end
        end
      end
      
      table.insert(file_lines_data, line_segments)
    end
    add_boxed_section("📄 ", "Recent Files", file_lines_data) -- Updated title
  end

  -- Helper for PR sections
  local function add_pr_section(title_icon, title_text, pr_list)
    if #pr_list == 0 then return end
    local pr_lines_data = {}
    for _, pr in ipairs(pr_list) do
      local state_icon_text
      if pr.state == "OPEN" then
        state_icon_text = "🟢"
      elseif pr.state == "CLOSED" then
        state_icon_text = "🔴"
      elseif pr.state == "MERGED" then
        state_icon_text = "🟣"
      else
        state_icon_text = "❓"
      end
      
      local pr_title_text = pr.title
      local pr_line_display = string.format("#%d %s %s", pr.number, state_icon_text, pr_title_text)
      if vim.fn.strwidth(pr_line_display) > 80 then
        local available_width = 80 - vim.fn.strwidth(string.format("#%d %s ", pr.number, state_icon_text)) - 3 -- for "..."
        if available_width > 5 then
            pr_title_text = pr_title_text:sub(1, math.floor(vim.fn.strwidth(pr_title_text) * available_width / vim.fn.strwidth(pr_title_text))) .. "..."
        else
            pr_title_text = "..."
        end
      end
      
      table.insert(pr_lines_data, {
        { text = "#" .. pr.number },
        { text = " " },
        { text = state_icon_text },
        { text = " " .. pr_title_text },
      })
      
      local author_line_text = "  by " .. pr.author .. ", " .. pr.time_ago
      if vim.fn.strwidth(author_line_text) > 80 then
        author_line_text = author_line_text:sub(1, 77) .. "..."
      end
      table.insert(pr_lines_data, {
          { text = "  by "},
          { text = pr.author },
          { text = ", " .. pr.time_ago }
      })
    end
    add_boxed_section(title_icon, title_text, pr_lines_data)
  end

  add_pr_section("🚀 ", "My Open PRs", my_created_prs)
  add_pr_section("👤 ", "PRs Assigned to Me", my_assigned_prs)
  add_pr_section("🆕 ", "Recently Created PRs", created_prs)
  add_pr_section("🔄 ", "Recently Updated PRs", updated_prs)
  
  -- Show helpful message when no PRs are found but we're in a git repo
  if #my_created_prs == 0 and #my_assigned_prs == 0 and #created_prs == 0 and #updated_prs == 0 and is_git_repo() then
    local remote_url = vim.fn.systemlist("git remote get-url origin 2>/dev/null")[1]
    if remote_url and remote_url:match("github%.com") then
      local pr_help_lines_data = {
        { {text = "No recent PRs found"} },
        { {text = "Press 'p' to view all PRs"} }
      }
      add_boxed_section("🔀 ", "Recent PRs", pr_help_lines_data)
    end
  end

  -- Most Changed Files section
  if #hotspots > 0 then
    local hotspot_lines_data = {}
    for i, hotspot in ipairs(hotspots) do
      local count_text = "[" .. hotspot.count .. "×] "
      local path_text = hotspot.relative_path
      
      local line_segments = {
        { text = count_text },
        { text = path_text }
      }
      
      -- Add diagnostic information if available
      if hotspot.diagnostics then
        local diagnostic_segments = add_diagnostic_segments(hotspot.diagnostics)
        for _, seg in ipairs(diagnostic_segments) do
          table.insert(line_segments, seg)
        end
      end
      
      local total_width = 0
      for _, seg in ipairs(line_segments) do
        total_width = total_width + vim.fn.strwidth(seg.text)
      end
      
      if total_width > 80 then
        local available_width = 80 - vim.fn.strwidth(count_text) - 3 -- for "..."
        -- Account for diagnostic text if present
        if hotspot.diagnostics then
          available_width = available_width - vim.fn.strwidth(format_diagnostic_counts(hotspot.diagnostics))
        end
        
        if available_width > 5 then
            line_segments[2].text = path_text:sub(1, math.max(1, available_width)) .. "..."
        else
            line_segments[2].text = "..."
            -- Remove diagnostic segments if we're out of space
            for j = #line_segments, 3, -1 do
              line_segments[j] = nil
            end
        end
      end
      
      table.insert(hotspot_lines_data, line_segments)
    end
    add_boxed_section("🔥 ", "Most Changed Files (last 3 months)", hotspot_lines_data)
  end
  
  -- Help section
  local help_lines_data = {
    { 
        {text = "r"}, {text = " - Refresh        "}, 
        {text = "f"}, {text = " - Find files      "}, 
        {text = "g"}, {text = " - Git status"}
    },
    { 
        {text = "b"}, {text = " - Bookmarks      "}, 
        {text = "p"}, {text = " - List PRs        "}, 
        {text = "q"}, {text = " - Close"}
    },
    { 
        {text = "1-9"}, {text = " - Jump to bookmark"}
    },
    { 
        {text = "Enter"}, {text = " - Open file/checkout PR  "}, 
        {text = "o"}, {text = " - Open PR in browser"}
    },
    { 
        {text = "h"}, {text = " - Show commit history (on commit lines)"}
    }
  }
  
  -- Add diagnostic info line if diagnostics are enabled
  if config.show_diagnostics then
    table.insert(help_lines_data, {
      {text = "File diagnostics: "}, 
      {text = " errors ", hl_group = "DashboardDiagnosticError"}, 
      {text = " warnings ", hl_group = "DashboardDiagnosticWarn"}, 
      {text = " info ", hl_group = "DashboardDiagnosticInfo"}, 
      {text = " hints", hl_group = "DashboardDiagnosticHint"}
    })
  end
  
  add_boxed_section("⌨️  ", "Quick Actions", help_lines_data)
  
  return lines_data
end

local function create_dashboard_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  local lines_data = create_dashboard_content()
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(buf, "filetype", "dashboard")
  vim.api.nvim_buf_set_option(buf, "buflisted", true)
  
  -- Set content and apply highlights
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  local raw_lines = {}
  for _, line_data in ipairs(lines_data) do
      local current_line_text = ""
      for _, segment in ipairs(line_data) do
          current_line_text = current_line_text .. segment.text
      end
      table.insert(raw_lines, current_line_text)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, raw_lines)
  
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  apply_commit_highlights(buf, lines_data)
  
  return buf
end

function M.switch_to_dashboard()
  -- Look for existing dashboard buffer
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf_id) and vim.api.nvim_buf_get_option(buf_id, "filetype") == "dashboard" then
      -- Find window displaying this buffer, or create one
      local wins = vim.fn.win_findbuf(buf_id)
      if #wins > 0 then
        vim.api.nvim_set_current_win(wins[1])
      else
        vim.api.nvim_set_current_buf(buf_id)
      end
      return true
    end
  end
  -- No existing dashboard found, create new one
  M.open_dashboard()
  return false
end

function M.open_dashboard()
  local repo_name = get_repo_name()
  local buf = create_dashboard_buffer()
  
  -- Use the current window instead of creating a floating window
  vim.api.nvim_set_current_buf(buf)
  
  -- Set up buffer-local keymaps
  local function set_keymap(key, action, desc)
    vim.api.nvim_buf_set_keymap(buf, "n", key, "", {
      noremap = true,
      silent = true,
      callback = action,
      desc = desc
    })
  end
  
  -- Function to open PR URL in browser
  local function open_pr_url()
    local line = vim.api.nvim_get_current_line()
    local pr_url = nil
    
    -- Strip box characters and padding if present
    local content = line
    if line:match("^│ .* │$") then
      content = line:match("^│ (.*) │$")
      if content then
        content = content:gsub("^%s+", ""):gsub("%s+$", "")
      end
    end
    
    -- Strip diagnostic information from the content before parsing
    -- Diagnostic format: [E2 W1 I3 H1] or [E2] or [W1 I3] etc.
    local content_without_diagnostics = content
    if content_without_diagnostics then
      content_without_diagnostics = content_without_diagnostics:gsub("%s+%[[EWIH0-9%s]+%]", "")
    end
    
    -- Parse PR format: "#123 🟢 Title of PR"
    local pr_number = content_without_diagnostics and content_without_diagnostics:match("^%s*#(%d+)%s+[🟢🔴🟣❓]")
    
    if pr_number then
      -- Get all PR data
      local commits = is_git_repo() and get_git_commits() or {}
      local hotspots = is_git_repo() and get_git_hotspots() or {}
      local bookmarks = get_current_bookmarks()
      local recent_files = get_recent_files()
      local created_prs, updated_prs, my_created_prs, my_assigned_prs = get_recent_prs()
      
      -- Look for the PR in all PR lists
      local all_prs = {}
      for _, pr in ipairs(my_created_prs) do table.insert(all_prs, pr) end
      for _, pr in ipairs(my_assigned_prs) do table.insert(all_prs, pr) end
      for _, pr in ipairs(created_prs) do table.insert(all_prs, pr) end
      for _, pr in ipairs(updated_prs) do table.insert(all_prs, pr) end
      
      for _, pr in ipairs(all_prs) do
        if tostring(pr.number) == pr_number then
          pr_url = pr.url
          break
        end
      end
      
      if pr_url then
        -- Open URL in browser
        local open_cmd
        if vim.fn.has("mac") == 1 then
          open_cmd = "open"
        elseif vim.fn.has("unix") == 1 then
          open_cmd = "xdg-open"
        elseif vim.fn.has("win32") == 1 then
          open_cmd = "start"
        else
          vim.notify("Unable to detect system to open URL", vim.log.levels.WARN)
          return
        end
        
        local cmd = open_cmd .. " " .. vim.fn.shellescape(pr_url)
        vim.fn.system(cmd)
        vim.notify("Opening PR #" .. pr_number .. " in browser", vim.log.levels.INFO)
      else
        vim.notify("Could not find URL for PR #" .. pr_number, vim.log.levels.WARN)
      end
    else
      vim.notify("No PR found on this line", vim.log.levels.INFO)
    end
  end

  -- Function to parse current line and open file
  local function open_file_from_line()
    local line = vim.api.nvim_get_current_line()
    local file_path = nil
    local line_number = nil
    local pr_url = nil
    
    -- Strip box characters and padding if present
    local content = line
    if line:match("^│ .* │$") then
      -- Extract content between box characters and trim padding
      content = line:match("^│ (.*) │$")
      if content then
        content = content:gsub("^%s+", ""):gsub("%s+$", "") -- trim leading and trailing whitespace
      end
    end
    
    -- Strip diagnostic information from the content before parsing
    -- Diagnostic format: [E2 W1 I3 H1] or [E2] or [W1 I3] etc.
    local content_without_diagnostics = content
    if content_without_diagnostics then
      content_without_diagnostics = content_without_diagnostics:gsub("%s+%[[EWIH0-9%s]+%]", "")
    end
    
    -- Parse PR format: "#123 🟢 Title of PR"
    local pr_number = content_without_diagnostics and content_without_diagnostics:match("^%s*#(%d+)%s+[🟢🔴🟣❓]") 
    
    if pr_number then
      -- Get all PR data from the current dashboard content
      local commits = is_git_repo() and get_git_commits() or {}
      local hotspots = is_git_repo() and get_git_hotspots() or {}
      local bookmarks = get_current_bookmarks()
      local recent_files = get_recent_files()
      local created_prs, updated_prs, my_created_prs, my_assigned_prs = get_recent_prs()
      
      -- Look for the PR in all PR lists
      local all_prs = {}
      for _, pr in ipairs(my_created_prs) do table.insert(all_prs, pr) end
      for _, pr in ipairs(my_assigned_prs) do table.insert(all_prs, pr) end
      for _, pr in ipairs(created_prs) do table.insert(all_prs, pr) end
      for _, pr in ipairs(updated_prs) do table.insert(all_prs, pr) end
      
      for _, pr in ipairs(all_prs) do
        if tostring(pr.number) == pr_number then
          -- Get the PR branch name using gh CLI
          local branch_cmd = string.format('gh pr view %s --json headRefName --jq .headRefName', pr_number)
          local branch_name = vim.fn.system(branch_cmd .. " 2>/dev/null"):gsub('\n', '')
          
          if vim.v.shell_error ~= 0 or branch_name == "" then
            vim.notify("Could not get branch name for PR #" .. pr_number, vim.log.levels.WARN)
            return
          end
          
          -- Fetch the latest changes
          vim.fn.system("git fetch origin")
          
          -- Checkout the PR branch
          local checkout_cmd = "git checkout " .. vim.fn.shellescape(branch_name)
          local checkout_result = vim.fn.system(checkout_cmd)
          
          if vim.v.shell_error ~= 0 then
            -- Try to checkout from origin if local branch doesn't exist
            checkout_cmd = "git checkout -b " .. vim.fn.shellescape(branch_name) .. " origin/" .. vim.fn.shellescape(branch_name)
            checkout_result = vim.fn.system(checkout_cmd)
            
            if vim.v.shell_error ~= 0 then
              vim.notify("Failed to checkout branch: " .. branch_name, vim.log.levels.ERROR)
              return
            end
          end
          
          vim.notify("Checked out PR #" .. pr_number .. " branch: " .. branch_name, vim.log.levels.INFO)
          
          -- Determine the main branch (origin/main or origin/master)
          local main_branch = "origin/main"
          local main_check = vim.fn.system("git rev-parse --verify origin/main 2>/dev/null")
          if vim.v.shell_error ~= 0 then
            main_branch = "origin/master"
            local master_check = vim.fn.system("git rev-parse --verify origin/master 2>/dev/null")
            if vim.v.shell_error ~= 0 then
              vim.notify("Could not find origin/main or origin/master branch", vim.log.levels.WARN)
              return
            end
          end
          
          -- Open diffview against main/master
          vim.cmd("DiffviewOpen " .. main_branch)
          vim.notify("Opened diffview against " .. main_branch, vim.log.levels.INFO)
          return
        end
      end
      
      vim.notify("Could not find PR #" .. pr_number, vim.log.levels.WARN)
      return
    end
    
    -- Parse commit format: "abc1234 Commit message (time ago)"
    local commit_hash = content_without_diagnostics and content_without_diagnostics:match("^([a-f0-9]+)%s+")
    if commit_hash and #commit_hash >= 7 then
      
      -- Open commit view using diffview
      vim.cmd("DiffviewOpen " .. commit_hash .. "^.." .. commit_hash)
      vim.notify("Opened commit view for " .. commit_hash, vim.log.levels.INFO)
      return
    end
    
    -- Parse bookmark format: "[1] name (path/to/file:123)"
    local bookmark_match = content_without_diagnostics and content_without_diagnostics:match("%[%d+%] .* %((.+):(%d+)%)$")
    if bookmark_match then
      file_path = content_without_diagnostics:match("%[%d+%] .* %((.+):%d+%)$")
      line_number = tonumber(content_without_diagnostics:match("%[%d+%] .* %.+:(%d+)%)$"))
    else
      -- Parse recent files format: "path/to/file (time ago)"
      local recent_file_match = content_without_diagnostics and content_without_diagnostics:match("^(.+) %(.+ ago%)$")
      if recent_file_match then
        file_path = recent_file_match
      else
        -- Parse hotspot format: "[5×] path/to/file"
        local hotspot_match = content_without_diagnostics and content_without_diagnostics:match("^%[%d+×%] (.+)$")
        if hotspot_match then
          file_path = hotspot_match
        end
      end
    end
    
    if file_path then
      -- Convert relative path to absolute if needed
      if not vim.startswith(file_path, "/") then
        local repo_root = get_repo_root()
        file_path = repo_root .. "/" .. file_path
      end
      
      -- Check if file exists
      if vim.fn.filereadable(file_path) == 1 then
        -- Add current position to jumplist before opening file
        vim.cmd("normal! m'")
        
        -- Open the file
        vim.cmd("edit " .. vim.fn.fnameescape(file_path))
        
        -- Jump to line if specified (for bookmarks)
        if line_number then
          vim.api.nvim_win_set_cursor(0, {line_number, 0})
        end
      else
        vim.notify("File not found: " .. file_path, vim.log.levels.WARN)
      end
    else
      vim.notify("No file or PR found on this line", vim.log.levels.INFO)
    end
  end
  
  -- Open file on Enter
  set_keymap("<CR>", open_file_from_line, "Open file under cursor")
  set_keymap("<Return>", open_file_from_line, "Open file under cursor")
  
  -- Open PR URL in browser on 'o'
  set_keymap("o", open_pr_url, "Open PR URL in browser")
  
  -- Close dashboard
  set_keymap("q", function() 
    vim.cmd("bdelete") 
  end, "Close dashboard")
  set_keymap("<Esc>", function() 
    vim.cmd("bdelete") 
  end, "Close dashboard")
  
  -- Refresh dashboard
  set_keymap("r", function()
    local lines_data = create_dashboard_content()
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    local raw_lines = {}
    for _, line_data in ipairs(lines_data) do
        local current_line_text = ""
        for _, segment in ipairs(line_data) do
            current_line_text = current_line_text .. segment.text
        end
        table.insert(raw_lines, current_line_text)
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, raw_lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    -- Apply highlighting after refresh
    apply_commit_highlights(buf, lines_data)
  end, "Refresh dashboard")
  
  -- Quick actions
  set_keymap("f", function()
    vim.cmd("Telescope find_files")
  end, "Find files")
  
  set_keymap("g", function()
    vim.cmd("Git")
  end, "Git status")
  
  set_keymap("b", function()
    local ok, bookmark_sets = pcall(require, 'myplugins.bookmark-sets')
    if ok then
      bookmark_sets.show_ui()
    else
      vim.notify("Bookmark sets plugin not available", vim.log.levels.WARN)
    end
  end, "Show bookmarks")
  
  set_keymap("p", function()
    vim.cmd("Octo pr list")
  end, "List PRs")
  
  -- Bookmark jumps (1-9)
  for i = 1, 9 do
    set_keymap(tostring(i), function()
      local ok, bookmark_sets = pcall(require, 'myplugins.bookmark-sets')
      if ok then
        bookmark_sets.jump_to_bookmark(i)
      else
        vim.notify("Bookmark sets plugin not available", vim.log.levels.WARN)
      end
    end, "Jump to bookmark #" .. i)
  end
  
  -- Function to show commit history/tree view
  local function show_commit_history()
    local line = vim.api.nvim_get_current_line()
    
    -- Strip box characters and padding if present
    local content = line
    if line:match("^│ .* │$") then
      content = line:match("^│ (.*) │$")
      if content then
        content = content:gsub("^%s+", ""):gsub("%s+$", "")
      end
    end
    
    -- Strip diagnostic information from the content before parsing
    -- Diagnostic format: [E2 W1 I3 H1] or [E2] or [W1 I3] etc.
    local content_without_diagnostics = content
    if content_without_diagnostics then
      content_without_diagnostics = content_without_diagnostics:gsub("%s+%[[EWIH0-9%s]+%]", "")
    end
    
    -- Parse commit format: "abc1234 Commit message (time ago)"
    local commit_hash = content_without_diagnostics and content_without_diagnostics:match("^([a-f0-9]+)%s+")
    if commit_hash and #commit_hash >= 7 then
      -- Check if Flog command exists without executing it
      if vim.fn.exists(":Flog") == 2 then
        -- Open Flog and navigate to the specific commit
        vim.cmd("Flog")
        -- Search for the commit hash in the flog buffer
        vim.fn.search(commit_hash)
        vim.notify("Opened git tree view at commit " .. commit_hash, vim.log.levels.INFO)
      else
        -- Fallback to fugitive git log with graph
        local fugitive_available = pcall(vim.cmd, "Git log --oneline --graph --decorate -20")
        if fugitive_available then
          -- Search for the commit hash
          vim.fn.search(commit_hash)
          vim.notify("Opened git log view at commit " .. commit_hash, vim.log.levels.INFO)
        else
          -- Final fallback to terminal git log
          vim.cmd("terminal git log --oneline --graph --decorate -20")
          vim.notify("Opened git log in terminal", vim.log.levels.INFO)
        end
      end
    else
      vim.notify("No commit found on this line", vim.log.levels.INFO)
    end
  end
  
  -- Open commit history on 'h'
  set_keymap("h", show_commit_history, "Show commit history/tree view")
  
  return buf
end

function M.refresh_dashboard()
  -- Find existing dashboard buffer and refresh it
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_option(buf, "filetype") == "dashboard" then
      vim.api.nvim_buf_set_option(buf, "modifiable", true)
      
      local lines_data = create_dashboard_content()
      local raw_lines = {}
      for _, line_data in ipairs(lines_data) do
          local current_line_text = ""
          for _, segment in ipairs(line_data) do
              current_line_text = current_line_text .. segment.text
          end
          table.insert(raw_lines, current_line_text)
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, raw_lines)
      
      vim.api.nvim_buf_set_option(buf, "modifiable", false)
      
      -- Apply highlighting after refresh
      apply_commit_highlights(buf, lines_data)
      return
    end
  end
end

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", default_config, user_config or {})
  
  -- Set up highlight groups for syntax highlighting
  setup_highlight_groups()
  
  -- Setup autocmd to re-apply highlights when colorscheme changes
  setup_highlight_autocmd()
  
  -- Create user commands
  vim.api.nvim_create_user_command("Dashboard", function()
    M.open_dashboard()
  end, { desc = "Open repository dashboard" })
  
  vim.api.nvim_create_user_command("DashboardRefresh", function()
    M.refresh_dashboard()
  end, { desc = "Refresh dashboard content" })
  
  -- Set up keymaps
  vim.keymap.set("n", "<leader>db", M.switch_to_dashboard, { 
    noremap = true, 
    silent = true, 
    desc = "Open repository dashboard" 
  })
  
  -- Track visited files
  vim.api.nvim_create_autocmd({"BufRead", "BufNewFile"}, {
    callback = function(args)
      local filepath = args.file
      if filepath and filepath ~= "" then
        -- Get the full path
        local full_path = vim.fn.fnamemodify(filepath, ":p")
        
        if vim.fn.filereadable(full_path) == 1 then
          -- Only track files in the current repo
          local repo_root = get_repo_root()
          
          if vim.startswith(full_path, repo_root) then
            track_visited_file(full_path)
          end
        end
      end
    end,
    desc = "Track visited files for dashboard"
  })
  
  -- Auto-open dashboard when starting nvim
  if config.auto_open then
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        -- Only open dashboard if no files were specified on command line
        -- This means it opens for "nvim" or "nvim ." but not "nvim file.txt"
        local argv = vim.fn.argv()
        local should_open = true
        
        -- Check if any command line arguments are actual files (not directories)
        for _, arg in ipairs(argv) do
          local full_path = vim.fn.fnamemodify(arg, ":p")
          -- If the argument is a file (not a directory), don't open dashboard
          if vim.fn.filereadable(full_path) == 1 then
            should_open = false
            break
          end
        end
        
        if should_open then
          M.open_dashboard()
          -- Also open nvim-tree when dashboard opens at startup
          vim.schedule(function()
            vim.cmd("NvimTreeOpen")
          end)
        end
      end,
    })
  end
  
  -- Auto-refresh dashboard when certain events occur (only when in dashboard buffer)
  vim.api.nvim_create_autocmd({"BufWritePost", "FocusGained"}, {
    callback = function()
      -- Only refresh if the current buffer is a dashboard buffer
      local current_buf = vim.api.nvim_get_current_buf()
      local filetype = vim.api.nvim_buf_get_option(current_buf, "filetype")
      if filetype == "dashboard" then
        M.refresh_dashboard()
      end
    end,
  })
end

return M

