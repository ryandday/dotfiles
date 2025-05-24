return {
  -- GitHub PR management
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    keys = {
      -- Core PR operations
      { "<leader>op", "<cmd>Octo pr list<cr>", desc = "List PRs" },
      { "<leader>oP", "<cmd>Octo pr create<cr>", desc = "Create PR" },
      { "<leader>or", "<cmd>Octo review start<cr>", desc = "Start PR Review" },
      
      -- My PRs
      { "<leader>oma", "<cmd>Octo pr list assignee:@me<cr>", desc = "My Assigned PRs" },
      { "<leader>omc", "<cmd>Octo pr list author:@me<cr>", desc = "My Created PRs" },
      
      -- Current branch PR
      { 
        "<leader>oc", 
        function()
          local current_branch = vim.fn.system("git branch --show-current"):gsub('\n', '')
          if current_branch and current_branch ~= "" then
            vim.cmd("Octo search is:pr head:" .. current_branch)
          else
            vim.notify("Not on a git branch", vim.log.levels.WARN)
          end
        end,
        desc = "Current Branch PR" 
      },
    },
    opts = {
      default_remote = { "upstream", "origin" },
      default_merge_method = "commit",
      picker = "telescope",
      mappings = {
        pull_request = {
          -- Essential PR actions
          checkout_pr = { lhs = "<space>po", desc = "checkout PR" },
          open_in_browser = { lhs = "<C-b>", desc = "open PR in browser" },
          reload = { lhs = "<C-r>", desc = "reload PR" },
          
          -- Comments
          add_comment = { lhs = "<space>ca", desc = "add comment" },
          delete_comment = { lhs = "<space>cd", desc = "delete comment" },
          next_comment = { lhs = "]c", desc = "go to next comment" },
          prev_comment = { lhs = "[c", desc = "go to previous comment" },
          
          -- Reactions
          react_thumbs_up = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
        },
        review_thread = {
          -- Review comments
          add_comment = { lhs = "<space>ca", desc = "add comment" },
          delete_comment = { lhs = "<space>cd", desc = "delete comment" },
          next_comment = { lhs = "]c", desc = "go to next comment" },
          prev_comment = { lhs = "[c", desc = "go to previous comment" },
          
          -- Reactions
          react_thumbs_up = { lhs = "<space>r+", desc = "add/remove 👍 reaction" },
        },
        review_diff = {
          -- Review actions
          submit_review = { lhs = "<leader>vs", desc = "submit review" },
          add_review_comment = { lhs = "<space>ca", desc = "add review comment" },
          
          -- Navigation
          next_thread = { lhs = "]t", desc = "move to next thread" },
          prev_thread = { lhs = "[t", desc = "move to previous thread" },
        },
      },
      picker_config = {
        use_telescope = true,
        mappings = {
          open_in_browser = { lhs = "<C-b>", desc = "open in browser" },
          checkout_pr = { lhs = "<C-o>", desc = "checkout pull request" },
        },
      },
    },
    config = function(_, opts)
      require("octo").setup(opts)
    end,
  },
} 