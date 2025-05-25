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
        "dart-debug-adapter",
        "dartls",
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
      "nvim-navic",
    },
    keys = {
      { "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", desc = "Go to Definition" },
      { "gs", "<cmd>lua vim.lsp.buf.document_symbol()<cr>", desc = "Document Symbols" },
      { "gS", "<cmd>lua vim.lsp.buf.workspace_symbol()<cr>", desc = "Workspace Symbols" },
      { "gr", "<cmd>lua vim.lsp.buf.references()<cr>", desc = "References" },
      { "gt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", desc = "Type Definition" },
      { "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<cr>", desc = "Rename" },
      { "K", "<cmd>lua vim.lsp.buf.hover()<cr>", desc = "Hover" },
      { "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", desc = "Code Action" },
      { "<leader>f", "<cmd>lua vim.lsp.buf.format({ async = true })<cr>", desc = "Format" },
      { "<leader>ch", "<cmd>lua vim.lsp.buf.incoming_calls()<cr>", desc = "Incoming Calls" },
      { "<leader>cH", "<cmd>lua vim.lsp.buf.outgoing_calls()<cr>", desc = "Outgoing Calls" },
      { "]g", "<cmd>lua vim.diagnostic.goto_next()<cr>", desc = "Next Diagnostic" },
      { "[g", "<cmd>lua vim.diagnostic.goto_prev()<cr>", desc = "Previous Diagnostic" },
      -- { "<leader>e", "<cmd>lua vim.diagnostic.open_float()<cr>", desc = "Show Diagnostic" },
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local navic = require("nvim-navic")

      -- Common on_attach function to setup navic
      local on_attach = function(client, bufnr)
        if client.server_capabilities.documentSymbolProvider then
          navic.attach(client, bufnr)
        end
      end

      -- C/C++ setup (clangd)
      lspconfig.clangd.setup({
        capabilities = capabilities,
        on_attach = on_attach,
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
        },
        -- Fix offset encoding to prevent multiple client encoding warnings
        offset_encoding = "utf-8",
      })

      -- Python setup
      lspconfig.pyright.setup({
        capabilities = capabilities,
        on_attach = on_attach,
      })

      -- Dart setup
      lspconfig.dartls.setup({
        capabilities = capabilities,
        on_attach = on_attach,
        cmd = { "dart", "language-server", "--protocol=lsp" },
        filetypes = { "dart" },
        init_options = {
          closingLabels = true,
          flutterOutline = true,
          onlyAnalyzeProjectsWithOpenFiles = true,
          outline = true,
          suggestFromUnimportedLibraries = true
        },
        settings = {
          dart = {
            completeFunctionCalls = true,
            showTodos = true,
          },
        },
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
