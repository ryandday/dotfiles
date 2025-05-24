-- Plugin configuration using vim-plug

-- Ensure vim-plug is installed
local vim = vim
local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.vim/plugged')

-- Fuzzy find
Plug('junegunn/fzf', { ['do'] = function() vim.fn['fzf#install']() end })
Plug('junegunn/fzf.vim')

-- Syntax, color
Plug('bfrg/vim-cpp-modern')
Plug('morhetz/gruvbox')

-- Editing tools
Plug('tpope/vim-surround')
Plug('tpope/vim-abolish')
Plug('tpope/vim-commentary')
Plug('tpope/vim-repeat')

-- Async
Plug('tpope/vim-dispatch')
Plug('nvim-lua/plenary.nvim')

-- Git
Plug('tpope/vim-fugitive')
Plug('tpope/vim-rhubarb')
Plug('airblade/vim-gitgutter')
Plug('rbong/vim-flog')

-- File explorer
Plug('preservim/nerdtree')
Plug('PhilRunninger/nerdtree-buffer-ops')
Plug('nvim-tree/nvim-web-devicons')

-- LSP
Plug('neovim/nvim-lspconfig')
Plug('williamboman/mason.nvim')
Plug('williamboman/mason-lspconfig.nvim')
Plug('nvimtools/none-ls.nvim')

-- Completion/snippets
Plug('hrsh7th/nvim-cmp')
Plug('hrsh7th/cmp-nvim-lsp')
Plug('hrsh7th/cmp-buffer')
Plug('hrsh7th/cmp-path')
Plug('hrsh7th/cmp-cmdline')
Plug('L3MON4D3/LuaSnip')
Plug('saadparwaiz1/cmp_luasnip')

-- Diagnostics
Plug('folke/trouble.nvim')
Plug('nvim-telescope/telescope.nvim')
Plug('nvim-treesitter/nvim-treesitter')
Plug('wellle/context.vim')

-- Debugging
Plug('epheien/termdbg') -- for lldb

-- Avante AI chat
Plug('zbirenbaum/copilot.lua')
Plug('stevearc/dressing.nvim')
Plug('MunifTanjim/nui.nvim')
Plug('MeanderingProgrammer/render-markdown.nvim')
Plug('HakonHarnes/img-clip.nvim')
Plug('yetone/avante.nvim', { branch = 'main', ['do'] = 'make' })

vim.call('plug#end')

-- Plugin configurations

-- Gruvbox colorscheme
vim.cmd('colorscheme gruvbox')
vim.opt.background = 'dark'

-- Termdbg settings
vim.g.termdebug_wide = 1

-- FZF default options
vim.env.FZF_DEFAULT_OPTS = "--bind ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down,ctrl-y:preview-up,ctrl-e:preview-down,ctrl-b:page-up,ctrl-f:page-down"

-- Setup LSP and completion in Lua
local function setup_lsp_and_completion()
  -- Mason setup
  require("mason").setup()
  require("mason-lspconfig").setup({
    ensure_installed = { "clangd", "pyright" },
    automatic_installation = true,
  })

  -- LSP configuration
  local lspconfig = require('lspconfig')
  local cmp_nvim_lsp = require('cmp_nvim_lsp')
  local capabilities = cmp_nvim_lsp.default_capabilities()

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

  -- Completion setup
  local cmp = require('cmp')
  local luasnip = require('luasnip')

  cmp.setup({
    snippet = {
      expand = function(args)
        luasnip.lsp_expand(args.body)
      end,
    },
    mapping = cmp.mapping.preset.insert({
      ['<Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_next_item()
        else
          fallback()
        end
      end),
      ['<S-Tab>'] = cmp.mapping(function(fallback)
        if cmp.visible() then
          cmp.select_prev_item()
        else
          fallback()
        end
      end),
      ['<CR>'] = cmp.mapping.confirm({ select = true }),
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'luasnip' },
      { name = 'buffer' },
      { name = 'path' },
    })
  })

  -- Trouble setup
  require("trouble").setup()
  
  -- Avante setup
  require('avante').setup()
end

-- Call the setup function
setup_lsp_and_completion() 