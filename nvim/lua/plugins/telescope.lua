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
          -- Check if we're currently in any nvim-tree window
          local current_buf = vim.api.nvim_get_current_buf()
          local buf_name = vim.api.nvim_buf_get_name(current_buf)
          
          if string.match(buf_name, "NvimTree_") then
            -- Switch to the other window
            vim.cmd("wincmd w")
          else
            -- Focus on nvim-tree
            api.tree.focus()
          end
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
          hint = "",
          info = "",
          warning = "",
          error = "",
        },
      },
    },
    config = function(_, opts)
      require("nvim-tree").setup(opts)
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
      { "<leader>gg", "<cmd>Telescope git_branches<cr>", desc = "Git Branches (Ctrl+W for worktree)" },
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
            ["<C-j>"] = "move_selection_next",
            ["<C-k>"] = "move_selection_previous",
            ["<C-u>"] = "preview_scrolling_up",
            ["<C-d>"] = "preview_scrolling_down",
            ["<C-b>"] = "preview_scrolling_up",
            ["<C-f>"] = "preview_scrolling_down",
            ["<C-y>"] = "preview_scrolling_up",
            ["<C-e>"] = "preview_scrolling_down",
            ["<C-S-u>"] = "results_scrolling_up",
            ["<C-S-d>"] = "results_scrolling_down",
          },
        },
      },
      pickers = {
        -- Git branches picker with worktree creation support
        -- Press Ctrl+W on any branch to create a worktree at ~/repos/<reponame>_<branchname>
        -- Special characters in branch names are replaced with underscores
        git_branches = {
          mappings = {
            i = {
              ["<C-w>"] = function(prompt_bufnr)
                local entry = require("telescope.actions.state").get_selected_entry()
                require("telescope.actions").close(prompt_bufnr)
                
                if entry then
                  local branch_name = entry.value
                  -- Remove origin/ prefix if present
                  branch_name = branch_name:gsub("^origin/", "")
                  
                  -- Get repository name
                  local repo_root = vim.fn.system("git rev-parse --show-toplevel"):gsub('\n', '')
                  local repo_name = vim.fn.fnamemodify(repo_root, ":t")
                  
                  -- Sanitize branch name (replace special chars with underscores)
                  local sanitized_branch = branch_name:gsub("[^%w%-]", "_")
                  
                  -- Create worktree directory path
                  local worktree_path = vim.fn.expand("~/repos/" .. repo_name .. "_" .. sanitized_branch)
                  
                  -- Check if directory already exists
                  if vim.fn.isdirectory(worktree_path) == 1 then
                    vim.notify("Worktree already exists at: " .. worktree_path, vim.log.levels.INFO)
                    -- Change to the existing worktree directory
                    vim.cmd("cd " .. worktree_path)
                    return
                  end
                  
                  -- Create the worktree
                  local cmd = string.format("git worktree add %s %s", worktree_path, branch_name)
                  local result = vim.fn.system(cmd)
                  
                  if vim.v.shell_error == 0 then
                    vim.notify("Created worktree: " .. worktree_path, vim.log.levels.INFO)
                    -- Change to the new worktree directory
                    vim.cmd("cd " .. worktree_path)
                    
                    -- Create and switch to tmux session if in tmux
                    if vim.env.TMUX then
                      local session_name = vim.fn.fnamemodify(worktree_path, ":t"):gsub("%.", "_")
                      
                      -- Create tmux session
                      local new_session_cmd = string.format("tmux new-session -ds %s -c %s", session_name, worktree_path)
                      local create_result = vim.fn.system(new_session_cmd)
                      
                      if vim.v.shell_error == 0 then
                        -- Start vim in the new session
                        local vim_cmd = string.format("tmux send-keys -t %s 'vim .' Enter", session_name)
                        vim.fn.system(vim_cmd)
                        
                        -- Switch to the session
                        local switch_cmd = string.format("tmux switch-client -t %s", session_name)
                        local switch_result = vim.fn.system(switch_cmd)
                        
                        if vim.v.shell_error == 0 then
                          vim.notify("Switched to tmux session: " .. session_name, vim.log.levels.INFO)
                        else
                          vim.notify("Failed to switch to tmux session: " .. switch_result, vim.log.levels.ERROR)
                        end
                      else
                        vim.notify("Failed to create tmux session: " .. create_result, vim.log.levels.ERROR)
                      end
                    end
                  else
                    vim.notify("Failed to create worktree: " .. result, vim.log.levels.ERROR)
                  end
                end
              end,
            },
            n = {
              ["<C-w>"] = function(prompt_bufnr)
                local entry = require("telescope.actions.state").get_selected_entry()
                require("telescope.actions").close(prompt_bufnr)
                
                if entry then
                  local branch_name = entry.value
                  -- Remove origin/ prefix if present
                  branch_name = branch_name:gsub("^origin/", "")
                  
                  -- Get repository name
                  local repo_root = vim.fn.system("git rev-parse --show-toplevel"):gsub('\n', '')
                  local repo_name = vim.fn.fnamemodify(repo_root, ":t")
                  
                  -- Sanitize branch name (replace special chars with underscores)
                  local sanitized_branch = branch_name:gsub("[^%w%-]", "_")
                  
                  -- Create worktree directory path
                  local worktree_path = vim.fn.expand("~/repos/" .. repo_name .. "_" .. sanitized_branch)
                  
                  -- Check if directory already exists
                  if vim.fn.isdirectory(worktree_path) == 1 then
                    vim.notify("Worktree already exists at: " .. worktree_path, vim.log.levels.INFO)
                    -- Change to the existing worktree directory
                    vim.cmd("cd " .. worktree_path)
                    return
                  end
                  
                  -- Create the worktree
                  local cmd = string.format("git worktree add %s %s", worktree_path, branch_name)
                  local result = vim.fn.system(cmd)
                  
                  if vim.v.shell_error == 0 then
                    vim.notify("Created worktree: " .. worktree_path, vim.log.levels.INFO)
                    -- Change to the new worktree directory
                    vim.cmd("cd " .. worktree_path)
                    
                    -- Create and switch to tmux session if in tmux
                    if vim.env.TMUX then
                      local session_name = vim.fn.fnamemodify(worktree_path, ":t"):gsub("%.", "_")
                      
                      -- Create tmux session
                      local new_session_cmd = string.format("tmux new-session -ds %s -c %s", session_name, worktree_path)
                      local create_result = vim.fn.system(new_session_cmd)
                      
                      if vim.v.shell_error == 0 then
                        -- Start vim in the new session
                        local vim_cmd = string.format("tmux send-keys -t %s 'vim .' Enter", session_name)
                        vim.fn.system(vim_cmd)
                        
                        -- Switch to the session
                        local switch_cmd = string.format("tmux switch-client -t %s", session_name)
                        local switch_result = vim.fn.system(switch_cmd)
                        
                        if vim.v.shell_error == 0 then
                          vim.notify("Switched to tmux session: " .. session_name, vim.log.levels.INFO)
                        else
                          vim.notify("Failed to switch to tmux session: " .. switch_result, vim.log.levels.ERROR)
                        end
                      else
                        vim.notify("Failed to create tmux session: " .. create_result, vim.log.levels.ERROR)
                      end
                    end
                  else
                    vim.notify("Failed to create worktree: " .. result, vim.log.levels.ERROR)
                  end
                end
              end,
            },
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
