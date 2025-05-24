return {
  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "NvimTreeToggle", "NvimTreeFindFile", "NvimTreeOpen" },
    keys = {
      { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "Toggle File Explorer" },
      { "<leader>o", function()
        local api = require("nvim-tree.api")
        if api.tree.is_visible() then
          api.tree.focus()
        else
          api.tree.open()
        end
      end, desc = "Open or Focus File Explorer" },
      { "-", "<cmd>NvimTreeFindFile<cr>", desc = "Find File in Explorer" },
    },
    opts = {
      disable_netrw = true,
      hijack_netrw = true,
      hijack_directories = {
        enable = true,
        auto_open = true,
      },
      sort_by = "case_sensitive",
      view = {
        width = 30,
        side = "left",
      },
      renderer = {
        group_empty = true,
        highlight_git = true,
        highlight_opened_files = "name",
        full_name = false,
        icons = {
          show = {
            file = true,
            folder = true,
            folder_arrow = true,
            git = true,
          },
          glyphs = {
            default = "",
            symlink = "",
            git = {
              unstaged = "●",
              staged = "✓",
              unmerged = "◍",
              renamed = "»",
              untracked = "◯",
              deleted = "✖",
              ignored = "◌",
            },
            folder = {
              arrow_closed = "",
              arrow_open = "",
              default = "",
              open = "",
              empty = "",
              empty_open = "",
              symlink = "",
              symlink_open = "",
            },
          },
        },
        indent_markers = {
          enable = true,
        },
      },
      filters = {
        dotfiles = false,
        custom = { "^.git$", "node_modules", ".cache" },
      },
      git = {
        enable = true,
        ignore = false,
        show_on_dirs = true,
        timeout = 500,
      },
      actions = {
        open_file = {
          quit_on_open = false,
          resize_window = true,
        },
        remove_file = {
          close_window = true,
        },
      },
      update_focused_file = {
        enable = true,
        update_cwd = true,
        ignore_list = {},
      },
      diagnostics = {
        enable = true,
        show_on_dirs = true,
        debounce_delay = 50,
        icons = {
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)
      
      -- Auto-open nvim-tree when starting vim with a directory
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("nvim-tree-start-directory", { clear = true }),
        desc = "Open nvim-tree on startup when starting with directory",
        callback = function(data)
          -- buffer is a directory
          local directory = vim.fn.isdirectory(data.file) == 1
          
          if directory then
            -- change to the directory
            vim.cmd.cd(data.file)
            -- open nvim-tree
            require("nvim-tree.api").tree.open()
          end
        end,
      })
    end,
  },

  -- Telescope for fuzzy finding
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    version = false, -- telescope did only one release, so use HEAD for now
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        enabled = vim.fn.executable("make") == 1,
        config = function()
          require("telescope").load_extension("fzf")
        end,
      },
    },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>ss", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
      { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live Grep" },
      { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help Tags" },
      -- LSP related
      { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
      { "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", desc = "Document Symbols" },
      { "<leader>fS", "<cmd>Telescope lsp_workspace_symbols<cr>", desc = "Workspace Symbols" },
      { "<leader>fr", "<cmd>Telescope lsp_references<cr>", desc = "References" },
      { "<leader>fi", "<cmd>Telescope lsp_implementations<cr>", desc = "Implementations" },
      -- Git related
      { "<leader>fc", "<cmd>Telescope git_commits<cr>", desc = "Git Commits" },
      { "<leader>fC", "<cmd>Telescope git_bcommits<cr>", desc = "Buffer Commits" },
      { "<leader>fb", "<cmd>Telescope git_branches<cr>", desc = "Git Branches" },
      -- Keymap search
      { "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Find Keymaps" },
      { "<leader>fK", "<cmd>Telescope commands<cr>", desc = "Find Commands" },
    },
    opts = {
      defaults = {
        prompt_prefix = " ",
        selection_caret = " ",
        mappings = {
          i = {
            ["<C-u>"] = false,
            ["<C-d>"] = false,
          },
        },
      },
    },
  },

  -- FZF for compatibility with existing mappings
  {
    "junegunn/fzf",
    build = function()
      vim.fn["fzf#install"]()
    end,
  },
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
    keys = {
      { "<leader>d", "<cmd>Rg<cr>", desc = "Ripgrep Search" },
      { "<leader>fn", ":grep! \"\" <left><left>", desc = "Grep Pattern" },
      { "<leader>fw", function()
        vim.cmd('grep! ' .. vim.fn.expand('<cword>'))
        vim.cmd('copen')
      end, desc = "Search Current Word" },
    },
    config = function()
      -- FZF default options (keeping your existing config)
      vim.env.FZF_DEFAULT_OPTS = "--bind ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down,ctrl-y:preview-up,ctrl-e:preview-down,ctrl-b:page-up,ctrl-f:page-down"
    end,
  },
} 
