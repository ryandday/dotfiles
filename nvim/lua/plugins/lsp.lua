return {
  -- Mason for managing LSP servers
  {
    "williamboman/mason.nvim",
    version = "v1.11.0",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    build = ":MasonUpdate",
    opts = {
      ensure_installed = {
        "clangd",
        "pyright",
      },
    },
    config = function(_, opts)
      require("mason").setup(opts)
    end,
  },

  -- Mason LSP config
  {
    "williamboman/mason-lspconfig.nvim",
    version = "v1.32.0",
    dependencies = { "mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "clangd", "pyright" },
        automatic_installation = true,
        automatic_enable = false,
      })
    end,
  },

  -- LSP Configuration
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason.nvim",
      "mason-lspconfig.nvim",
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- C/C++ setup (clangd)
      lspconfig.clangd.setup({
        capabilities = capabilities,
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders",
          "--fallback-style=llvm",
        },
        root_dir = lspconfig.util.root_pattern(
          '.clangd',
          '.clang-tidy',
          '.clang-format',
          'compile_commands.json',
          'compile_flags.txt',
          '.ccls',
          '.git'
        ),
        init_options = {
          cache = {
            directory = vim.fn.expand('~/.cache/clangd')
          }
        }
      })

      -- Python setup
      lspconfig.pyright.setup({
        capabilities = capabilities,
      })

      -- Diagnostic configuration
      vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })
    end,
  },

  -- None-ls for additional formatting/linting
  {
    "nvimtools/none-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = function()
      local nls = require("null-ls")
      return {
        root_dir = require("null-ls.utils").root_pattern(".null-ls-root", ".neoconf.json", "Makefile", ".git"),
        sources = {
          -- Formatting
          nls.builtins.formatting.prettier,
          nls.builtins.formatting.black.with({ extra_args = { "--fast" } }),
          nls.builtins.formatting.clang_format,
        },
      }
    end,
  },
} 
