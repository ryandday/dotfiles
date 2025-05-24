return {
  -- Quicker.nvim - Improved UI and workflow for the Neovim quickfix
  {
    "stevearc/quicker.nvim",
    event = "FileType qf",
    ---@module "quicker"
    ---@type quicker.SetupOptions
    opts = {
      -- Keymap configuration
      keys = {
        {
          ">",
          function()
            require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
          end,
          desc = "Expand quickfix context",
        },
        {
          "<",
          function()
            require("quicker").collapse()
          end,
          desc = "Collapse quickfix context",
        },
      },
      -- Display configuration
      highlight = {
        -- Use treesitter highlighting for the text in the quickfix
        treesitter = true,
        -- LSP semantic token highlighting for the text in the quickfix
        lsp = true,
      },
      -- Options for when to close the quickfix window
      close_with_one_key = true,
      -- Number of lines of context to show by default
      context = {
        before = 2,
        after = 2,
      },
      -- Max number of items to show in the quickfix
      max_height = 16,
      min_height = 4,
      -- How to format each quickfix item
      format = {
        -- Function to format each item. Return a string or table of strings.
        -- If a table, each element will be displayed on a separate line.
        -- item: QuickfixItem - the original quickfix item
        -- ctx: table - contains various context information
        -- Returns: string | string[]
        item = function(item, ctx)
          -- You can customize the format here
          -- Default format includes filename, line number, and text
          return string.format(
            "%s:%d: %s",
            vim.fn.fnamemodify(item.filename or "", ":t"),
            item.lnum or 0,
            item.text or ""
          )
        end,
      },
    },
    keys = {
      {
        "<leader>qo",
        function()
          require("quicker").toggle()
        end,
        desc = "Toggle quickfix",
      },
      {
        "<leader>qe",
        function()
          require("quicker").expand({ before = 2, after = 2 })
        end,
        desc = "Expand quickfix context",
      },
      {
        "<leader>qc",
        function()
          require("quicker").collapse()
        end,
        desc = "Collapse quickfix context",
      },
      {
        "<leader>ql",
        function()
          require("quicker").toggle({ loclist = true })
        end,
        desc = "Toggle loclist",
      },
    },
    config = function(_, opts)
      require("quicker").setup(opts)
    end,
  },
} 