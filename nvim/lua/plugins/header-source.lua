return {
  -- Header/Source file switcher
  {
    "header-source-switcher",
    dir = vim.fn.stdpath("config"),
    keys = {
      { "<leader>th", function() require("myplugins.header-source-switcher").switch() end, desc = "Switch Header/Source" },
      { "<leader>tp", function() require("myplugins.header-source-switcher").switch() end, desc = "Switch Header/Source" },
    },
    config = function()
      -- Plugin is ready to use
    end,
  },
} 