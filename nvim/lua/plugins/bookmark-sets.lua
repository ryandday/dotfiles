-- Bookmark Sets Plugin Configuration
return {
  {
    -- This is a local plugin so we specify the path
    dir = vim.fn.stdpath("config") .. "/lua/myplugins",
    name = "bookmark-sets",
    priority = 1000, -- Load early
    config = function()
      local bookmark_sets = require('myplugins.bookmark-sets')
      
      bookmark_sets.setup({
        -- Store bookmarks in a dedicated file
        data_path = vim.fn.stdpath("data") .. "/bookmark-sets.json",
        
        -- Auto-save changes (recommended)
        auto_save = true,
        
        -- Number of recent sets to remember
        max_recent_sets = 15,
        
        -- Enable quick numbered jumps (1-9)
        enable_numbered_jumps = true,
      })
    end,
  }
} 