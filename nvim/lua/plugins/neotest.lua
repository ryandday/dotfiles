return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",
      "alfaix/neotest-gtest",
    },
    keys = {
      { "<leader>tr", function() require("neotest").run.run() end, desc = "Run nearest test" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "Run current file" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "Toggle test summary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true }) end, desc = "Show test output" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "Toggle output panel" },
      { "<leader>tS", function() require("neotest").run.stop() end, desc = "Stop test run" },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-gtest").setup({
            -- Optional configuration
            debug = false,  -- Enable debug mode
            filter_dir = function(name, rel_path, root)
              return name ~= "build" and name ~= ".git"
            end,
          }),
        },
        -- General neotest configuration
        status = {
          virtual_text = true,
          signs = true,
        },
        output = {
          open_on_run = false,
        },
        quickfix = {
          open = false,
        },
      })
    end,
  },
} 