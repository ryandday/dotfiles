return {
  "akinsho/flutter-tools.nvim",
  lazy = true,
  ft = "dart",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "stevearc/dressing.nvim", -- optional for vim.ui.select
    "neovim/nvim-lspconfig",
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
  config = function()
    -- Get the common capabilities from cmp_nvim_lsp
    local capabilities = require('cmp_nvim_lsp').default_capabilities()
    
    -- Get navic for breadcrumbs support
    local navic = require("nvim-navic")

    -- Reuse the common on_attach function from your LSP config
    local on_attach = function(client, bufnr)
      -- Enable navic (breadcrumbs) if supported
      if client.server_capabilities.documentSymbolProvider then
        navic.attach(client, bufnr)
      end

      -- Enable formatting on save
      if client.server_capabilities.documentFormattingProvider then
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({ async = false })
          end,
        })
      end
    end

    require("flutter-tools").setup({
      ui = {
        -- the border type to use for all floating windows, the same options/formats
        -- used for ":h nvim_open_win" e.g. "single" | "shadow" | {<table-of-eight-chars>}
        border = "rounded",
        notification_style = "native",
      },
      decorations = {
        statusline = {
          -- set to true to be able use the 'flutter_tools_decorations.app_version' in your statusline
          app_version = true,
          -- set to true to be able use the 'flutter_tools_decorations.device' in your statusline
          device = true,
        },
      },
      debugger = {
        enabled = true,
        run_via_dap = true,
        register_configurations = function(_)
          require("dap").configurations.dart = {}
          require("dap").configurations.dart = {
            {
              type = "dart",
              request = "launch",
              name = "Launch Flutter",
              dartSdkPath = "/opt/homebrew/opt/dart/libexec",
              flutterSdkPath = "/opt/homebrew/opt/flutter",
              program = "${workspaceFolder}/lib/main.dart",
              cwd = "${workspaceFolder}",
            },
          }
        end,
      },
      flutter_path = "/opt/homebrew/bin/flutter",
      widget_guides = {
        enabled = true,
      },
      closing_tags = {
        highlight = "ErrorMsg",
        prefix = "//",
        enabled = true,
      },
      lsp = {
        color = {
          enabled = true,
          background = false,
          virtual_text = true,
        },
        settings = {
          showTodos = true,
          completeFunctionCalls = true,
          enableSnippets = true,
          updateImportsOnRename = true,
          renameFilesWithClasses = "prompt",
          enableSdkFormatter = true,
          analysisExcludedFolders = {
            "/opt/homebrew/opt/flutter/",
            vim.fn.expand("$HOME/.pub-cache/"),
          },
        },
        capabilities = capabilities,
        on_attach = on_attach,
      },
      dev_tools = {
        autostart = false,
        auto_open_browser = false,
      },
      outline = {
        auto_open = false,
      },
      -- Enable Mason integration
      root_dir = require("lspconfig.util").root_pattern(
        "pubspec.yaml",
        ".git"
      ),
    })

    -- Add telescope integration if available
    local ok, telescope = pcall(require, "telescope")
    if ok then
      telescope.load_extension("flutter")
    end
  end,
} 