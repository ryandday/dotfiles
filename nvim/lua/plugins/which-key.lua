return {
  -- Which-key for keybinding help
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      plugins = { spelling = true },
      defaults = {
        mode = { "n", "v" },
        ["<leader>f"] = { name = "+find" },
        ["<leader>g"] = { name = "+git" },
        ["<leader>l"] = { name = "+location list" },
        ["<leader>c"] = { name = "+code" },
        ["<leader>t"] = { name = "+toggle/test" },
        ["<leader>x"] = { name = "+diagnostics" },
      },
    },
    config = function(_, opts)
      local wk = require("which-key")
      wk.setup(opts)
      wk.register(opts.defaults)
    end,
  },
}
