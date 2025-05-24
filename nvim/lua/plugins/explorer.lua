return {
  -- File explorer
  {
    "preservim/nerdtree",
    cmd = { "NERDTree", "NERDTreeToggle", "NERDTreeFind", "NERDTreeFocus" },
    dependencies = {
      "PhilRunninger/nerdtree-buffer-ops",
    },
  },

  -- Icons for various plugins
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
} 