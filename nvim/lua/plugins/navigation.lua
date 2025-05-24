return {
  -- Nvim-navic - LSP breadcrumbs
  {
    "SmiteshP/nvim-navic",
    lazy = true,
    init = function()
      vim.g.navic_silence = true
    end,
    opts = function()
      return {
        separator = " ", -- separator between nodes
        depth_limit = 0, -- how many nodes to show (0 = show all)
        depth_limit_indicator = "..", -- indicator when depth limit is reached
        safe_output = true, -- escape unsafe characters in navic output
        lazy_update_context = false, -- update context on CursorHold instead of CursorMoved
        click = false, -- single click to go to location
        format_text = function(text)
          return text
        end,
        highlight = false,
        icons = {
          File          = "󰈙 ",
          Module        = " ",
          Namespace     = "󰌗 ",
          Package       = " ",
          Class         = "󰌗 ",
          Method        = "󰆧 ",
          Property      = " ",
          Field         = " ",
          Constructor   = " ",
          Enum          = "󰕘",
          Interface     = "󰕘",
          Function      = "󰊕 ",
          Variable      = "󰆧 ",
          Constant      = "󰏿 ",
          String        = " ",
          Number        = "󰎠 ",
          Boolean       = "◩ ",
          Array         = "󰅪 ",
          Object        = "󰅩 ",
          Key           = "󰌋 ",
          Null          = "󰟢 ",
          EnumMember    = " ",
          Struct        = "󰌗 ",
          Event         = " ",
          Operator      = "󰆕 ",
          TypeParameter = "󰊄 ",
        },
      }
    end,
    config = function(_, opts)
      require("nvim-navic").setup(opts)
    end,
  },
} 