return {
  -- Treesitter for syntax highlighting and more
  {
    "nvim-treesitter/nvim-treesitter",
    version = false, -- last release is way too old and doesn't work on Windows
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
    },
    opts = {
      highlight = { enable = true },
      indent = { enable = true },
      ensure_installed = {
        "bash",
        "c",
        "cpp",
        "lua",
        "python",
        "vim",
        "vimdoc",
        "markdown",
        "markdown_inline",
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- Modern C++ syntax highlighting
  {
    "bfrg/vim-cpp-modern",
    ft = { "cpp", "c", "h", "hpp" },
  },

  -- Context showing current function/class
  {
    "wellle/context.vim",
    event = { "BufReadPre", "BufNewFile" },
  },
} 