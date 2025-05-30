return {
  -- AWS resource explorer plugin
  {
    dir = vim.fn.expand("~/repos/dotfiles/nvim/lua/myplugins/aws-nvim"),
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons"
    },
    cmd = {
      "AWSNvimOpen",
      "AWSNvimStack",
      "AWSNvimRefresh",
      "AWSNvimFilter",
      "AWSNvimProfile",
      "AWSNvimRegion",
      "AwsClearCache",
    },
    keys = {
      { "<leader>aws", "<cmd>AWSNvimOpen<cr>", desc = "Open AWS Explorer" },
      { "<leader>awf", "<cmd>AWSNvimFilter<cr>", desc = "Filter AWS Resources" },
      { "<leader>awr", "<cmd>AWSNvimRegion<cr>", desc = "Change AWS Region" },
      { "<leader>awp", "<cmd>AWSNvimProfile<cr>", desc = "Change AWS Profile" },
      { "<leader>awx", "<cmd>AwsClearCache<cr>", desc = "Clear AWS Cache" },
    },
    opts = {
      -- AWS settings
      region = "us-east-1",
      profile = "", -- Empty string will use default AWS profile
      
      -- Cache settings
      cache_ttl = {
        stack = 600,    -- 10 minutes
        service = 300,  -- 5 minutes
        task = 120,     -- 2 minutes
        container = 60  -- 1 minute
      },
      
      -- UI settings
      split_direction = "right",
      width = 40,
      height = 20,
      
      -- Visual indicators
      icons = {
        expanded = "▼",
        collapsed = "▶",
        leaf = " ",
        loading = "⟳",
        status = {
          ok = "✓",
          warning = "⚠",
          error = "✗",
          unknown = "?"
        }
      }
    },
    config = function(_, opts)
      require("aws-nvim").setup(opts)
    end,
  }
}
