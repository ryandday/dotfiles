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
    opts = {
      file_types = { "markdown", "Avante" },
    },
  },

  -- Image clipboard
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
      default = {
        embed_image_as_base64 = false,
        prompt_for_file_name = false,
        drag_and_drop = {
          insert_mode = true,
        },
        use_absolute_path = true,
      },
    },
  },

  -- GitHub Copilot (configured for Avante only, no auto suggestions)
  -- Only loads when AVANTE_PROVIDER=copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    cond = function()
      return os.getenv("AVANTE_PROVIDER") == "copilot"
    end,
    config = function()
      require("copilot").setup({
        panel = {
          enabled = false, -- Disable panel since we're using Avante
        },
        suggestion = {
          enabled = false, -- Disable auto suggestions - only use with Avante
        },
        filetypes = {
          yaml = false,
          markdown = false,
          help = false,
          gitcommit = false,
          gitrebase = false,
          hgcommit = false,
          svn = false,
          cvs = false,
          ["."] = false,
        },
        copilot_node_command = 'node',
      })
    end,
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

  -- Avante AI chat with Copilot (Claude) integration
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
        -- Copilot configuration (will use Claude models when selected in GitHub Copilot)
        -- To use Claude 4: In VS Code, run "GitHub Copilot: Change Chat Model" and select Claude Sonnet 4 or Claude Opus 4
        copilot = {
          model = "claude-4.0-sonnet",
          temperature = 0.6,
          max_tokens = 4096,
          timeout = 30000,
        },
        -- Gemini configuration (good fallback for computers without Copilot)
        gemini = {
          model = "gemini-2.5-flash-preview-05-20",
          temperature = 0.6,
          max_tokens = 4096,
          timeout = 30000,
        },
        -- MCP integration
        mcp = {
          enabled = true,  -- Enable MCP integration
          use_mcphub = true,  -- Use MCPHub for server management
        },
        -- Behavior settings
        behaviour = {
          auto_suggestions = false,
          auto_set_highlight_group = true,
          auto_set_keymaps = true,
          auto_apply_diff_after_generation = false,
          support_paste_from_clipboard = false,
        },
        -- Windows configuration
        windows = {
          position = "right",
          width = 30,
          sidebar_header = {
            enabled = true,
            align = "center",
            rounded = true,
          },
        },
      })
    end,
  },
}
