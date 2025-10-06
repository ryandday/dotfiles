-- Repository Dashboard Plugin Configuration
-- DISABLED: Dashboard plugin is currently commented out
return {}

--[[
return {
  {
    -- This is a local plugin so we specify the path
    dir = vim.fn.stdpath("config") .. "/lua/myplugins",
    name = "dashboard",
    priority = 1000, -- Load early
    config = function()
      local dashboard = require('myplugins.dashboard')

      dashboard.setup({
        -- Auto-open dashboard when starting nvim (set to true to show on startup)
        auto_open = false,

        -- Number of items to show in each section
        git_max_commits = 5,
        max_recent_edits = 8,
        max_bookmarks = 8,
        max_hotspot_files = 8,
        max_recent_prs_created = 5,
        max_recent_prs_updated = 5,

        -- Dashboard window size
        width = 85,
        height = 35,
      })
    end,
  }
}
--]] 