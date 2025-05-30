return {
  -- UI improvements
  {
    "stevearc/dressing.nvim",
    lazy = true,
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
  },

  -- UI components
  {
    "MunifTanjim/nui.nvim",
    lazy = true,
  },

  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    opts = {},
  },

  -- Image clipboard
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- MCPHub - MCP Server Manager
  {
    "ravitemer/mcphub.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      integrations = {
        avante = true,  -- Enable Avante integration
      },
      auto_install = true,  -- Automatically install servers when needed
    },
  },

  -- Avante AI chat
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    build = "make",
    dependencies = {
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "HakonHarnes/img-clip.nvim",
      "MeanderingProgrammer/render-markdown.nvim",
      "ravitemer/mcphub.nvim",  -- Add MCPHub as dependency
      "zbirenbaum/copilot.lua", -- Required for copilot provider
    },
    config = function()
      -- Get provider from environment variable, default to gemini
      local provider = os.getenv("AVANTE_PROVIDER") or "gemini"
      
      require("avante").setup({
        provider = provider,
        gemini = {
          model = "gemini-2.5-flash-preview-05-20",
          temperature = 0.6,
          max_tokens = 4096,
          timeout = 30000,
        },
        copilot = {
          model = "gpt-4o-2024-08-06",
          temperature = 0.6,
          max_tokens = 4096,
          timeout = 30000,
        },
        mcp = {
          enabled = true,  -- Enable MCP integration
          use_mcphub = true,  -- Use MCPHub for server management
        },
      })
    end,
  },
}
