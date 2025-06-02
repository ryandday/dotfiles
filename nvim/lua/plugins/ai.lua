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

  -- Progress notifications with fidget.nvim
  {
    "j-hui/fidget.nvim",
    tag = "legacy", -- Use legacy version for compatibility
    event = "VeryLazy",
    config = function()
      require("fidget").setup({
        text = {
          spinner = "dots_negative", -- Spinner animation style
          done = "", -- Character shown when all tasks are complete
          commenced = "Started", -- Message shown when task starts
          completed = "Completed", -- Message shown when task completes
        },
        align = {
          bottom = true, -- Align notifications to bottom
          right = true,  -- Align notifications to right
        },
        timer = {
          spinner_rate = 125, -- Frame rate for spinner animation
          fidget_decay = 2000, -- How long to keep around empty fidget, in ms
          task_decay = 1000, -- How long to keep around completed task, in ms
        },
        window = {
          relative = "win", -- where to anchor, either "win" or "editor"
          blend = 100,      -- &winblend for the window
          zindex = nil,     -- the zindex value for the window
          border = "none",  -- style of border for the fidget window
        },
        fmt = {
          leftpad = true, -- right-justify text in fidget box
          stack_upwards = true, -- list of tasks grows upwards
          max_width = 0, -- maximum width of the fidget box
          fidget = function(fidget_name, spinner)
            return string.format("%s %s", spinner, fidget_name)
          end,
          task = function(task_name, message, percentage)
            return string.format(
              "%s%s [%s]",
              message,
              percentage and string.format(" (%s%%)", percentage) or "",
              task_name
            )
          end,
        },
      })
    end,
  },

  -- Markdown rendering
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = "markdown",
    opts = {
      file_types = { "markdown", "codecompanion" },
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

  -- VectorCode - Code repository indexing for enhanced LLM context
  {
    "Davidyz/VectorCode",
    cmd = { "VectorCode" },
    config = function()
      require("vectorcode").setup({
        -- Default configuration
        cmd = "vectorcode", -- Path to vectorcode CLI
        debug = false,
      })
    end,
    keys = {
      { "<leader>vc", "<cmd>VectorCode<cr>", desc = "VectorCode Search" },
      { "<leader>vi", "<cmd>VectorCode index<cr>", desc = "VectorCode Index Project" },
      { "<leader>vq", "<cmd>VectorCode query<cr>", desc = "VectorCode Query" },
    },
  },

  -- GitHub Copilot (optional, for copilot provider)
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    cond = function()
      return os.getenv("CODECOMPANION_PROVIDER") == "copilot"
    end,
    config = function()
      require("copilot").setup({
        panel = {
          enabled = false,
        },
        suggestion = {
          enabled = false, -- Disable auto suggestions
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

  -- CodeCompanion - Modern AI coding assistant
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "hrsh7th/nvim-cmp", -- Optional: for enhanced completion
      "nvim-telescope/telescope.nvim", -- Optional: for enhanced picking
      "stevearc/dressing.nvim", -- Optional: for enhanced UI
      "echasnovski/mini.diff",
      "j-hui/fidget.nvim", -- For progress notifications
      {
        "zbirenbaum/copilot.lua",
        cond = function()
          return os.getenv("CODECOMPANION_PROVIDER") == "copilot"
        end,
      },
    },
    config = function()
      -- Get provider from environment variable, default to claude
      local provider = os.getenv("CODECOMPANION_PROVIDER") or "gemini"
      
      -- Enable auto-approval of tool usage
      vim.g.codecompanion_auto_tool_mode = true
      
      require("codecompanion").setup({
        strategies = {
          chat = {
            adapter = provider,
          },
          inline = {
            adapter = provider,
          },
          agent = {
            adapter = provider,
          },
        },
        adapters = {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = {
                  default = "claude-3.7-sonnet", -- Latest Claude model available
                },
              },
            })
          end,
          gemini = function()
            return require("codecompanion.adapters").extend("gemini", {
              env = {
                api_key = "GEMINI_API_KEY",
              },
              schema = {
                model = {
                  default = "gemini-2.5-flash",
                },
                max_tokens = {
                  default = 8192,
                },
                temperature = {
                  default = 0.1,
                },
              },
            })
          end,
        },
        opts = {
          log_level = "ERROR", -- Set to "DEBUG" for troubleshooting
          send_code = true, -- Send code context to the LLM
          use_default_actions = true, -- Use the default actions
          use_default_prompts = true, -- Use the default prompts
          use_default_tools = true, -- Enable default tools
          auto_submit_errors = true, -- Auto-submit errors without confirmation
          auto_submit_success = true, -- Auto-submit success without confirmation
        },
        display = {
          action_palette = {
            provider = "telescope", -- or "mini_pick" or "default"
          },
          chat = {
            window = {
              layout = "vertical", -- float|vertical|horizontal|buffer
              width = 0.45,
              height = 0.8,
              relative = "editor",
              opts = {
                breakindent = true,
                cursorcolumn = false,
                cursorline = false,
                foldcolumn = "0",
                linebreak = true,
                list = false,
                signcolumn = "no",
                spell = false,
                wrap = true,
              },
            },
          },
          diff = {
            provider = "mini_diff", -- default|mini_diff
          },
        },
        keymaps = {
          -- In normal mode
          ["<leader>ac"] = "cmd:CodeCompanionActions", -- Open action palette
          ["<leader>aa"] = "cmd:CodeCompanionChat Toggle", -- Toggle chat (FIXED)
          ["<leader>ad"] = "cmd:CodeCompanionChat Add", -- Add visual selection to chat (FIXED)
          
          -- In visual mode  
          ["<leader>ad"] = "cmd:CodeCompanionChat Add", -- Add selection to chat (FIXED)
          ["<leader>ac"] = "cmd:CodeCompanionActions", -- Open action palette
        },
        -- -- Disable inline suggestions to avoid conflicts
        -- inline = {
        --   layout = "vertical", -- vertical|horizontal|buffer
        -- },
      })
      
      -- Initialize fidget integration for CodeCompanion progress notifications
      -- Ensure fidget.nvim is loaded before initializing the integration
      vim.defer_fn(function()
        local fidget_ok, _ = pcall(require, "fidget")
        if fidget_ok then
          require("myplugins.codecompanion-fidget"):init()
        else
          vim.notify("fidget.nvim not loaded, skipping CodeCompanion fidget integration", vim.log.levels.WARN)
        end
      end, 100) -- Small delay to ensure fidget is loaded
    end,
    cmd = {
      "CodeCompanion",
      "CodeCompanionActions",
      "CodeCompanionToggle",
      "CodeCompanionAdd",
      "CodeCompanionChat",
    },
    keys = {
      { "<leader>ac", "<cmd>CodeCompanionActions<cr>", mode = { "n", "v" }, desc = "CodeCompanion Actions" },
      { "<leader>aa", "<cmd>CodeCompanionChat Toggle<cr>", mode = { "n", "v" }, desc = "Toggle CodeCompanion" },
      { "<leader>ad", "<cmd>CodeCompanionChat Add<cr>", mode = { "v" }, desc = "Add to CodeCompanion" },
    },
  },
}
