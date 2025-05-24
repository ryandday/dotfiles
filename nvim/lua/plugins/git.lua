return {
  -- Git integration
  {
    "tpope/vim-fugitive",
    cmd = { "G", "Git", "Gdiffsplit", "Gread", "Gwrite", "Ggrep", "GMove", "GDelete", "GBrowse", "GRemove", "GRename", "Glgrep", "Gedit" },
    ft = { "fugitive" },
    keys = {
      { "<leader>gd", "<cmd>Gvdiffsplit<cr>", desc = "Git Diff Split" },
      { "<leader>gs", "<cmd>G<cr>", desc = "Git Status" },
      { "<leader>gp", "<cmd>G push<cr>", desc = "Git Push" },
      { "<leader>gb", "<cmd>G blame<cr>", desc = "Git Blame" },
      { "<leader>gl", "<cmd>Gclog<cr>", desc = "Git Log" },
      { "<leader>gg", "<cmd>Gbranch<cr>", desc = "Git Branch" },
    },
  },

  -- GitHub integration
  {
    "tpope/vim-rhubarb",
    dependencies = { "tpope/vim-fugitive" },
  },

  -- Git signs in gutter
  {
    "airblade/vim-gitgutter",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Git log viewer
  {
    "rbong/vim-flog",
    dependencies = { "tpope/vim-fugitive" },
    cmd = { "Flog", "Flogsplit", "Floggit" },
    keys = {
      { "<leader>gf", "<cmd>Flogsplit -path=%<cr>", desc = "Git File History", mode = "n" },
      { "<leader>gf", "<cmd>Flog<cr>", desc = "Git History", mode = "v" },
    },
  },
} 