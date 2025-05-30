return {
  -- Which-key for keybinding help
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "modern",
      delay = function(ctx)
        return ctx.plugin and 0 or 200
      end,
      spec = {
        -- Group definitions for better organization
        { "<leader>c", group = "Code" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
        { "<leader>gw", group = "Worktree" },
        { "<leader>l", group = "Location List" },
        { "<leader>r", group = "Replace/Rename" },
        { "<leader>t", group = "Tabs & Terminal" },
        { "<leader>x", group = "Diagnostics" },
        { "<leader>y", group = "Yank" },
        { "<leader>d", group = "Debug/Dashboard" },
        { "<leader>h", group = "Help" },
        { "]", group = "Next" },
        { "[", group = "Previous" },
        -- Space-based groups
        { "<space>a", group = "AI" },
        { "<space>b", group = "Bookmarks" },
        { "<space>o", group = "GitHub" },
        -- Leader-based groups
        { "<leader>q", group = "Quickfix" },
      },
      icons = {
        breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
        separator = "➜", -- symbol used between a key and it's label
        group = "+", -- symbol prepended to a group
      },
      win = {
        border = "rounded",
        padding = { 1, 2 },
      },
    },
    keys = {
      {
        "<leader>h?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
      {
        "<leader>?",
        function()
          require("which-key").show({ global = true })
        end,
        desc = "Global Keymaps (which-key)",
      },
      {
        "<leader>ht",
        "<cmd>Telescope builtin<cr>",
        desc = "Telescope Builtins",
      },
    },
  }
}
