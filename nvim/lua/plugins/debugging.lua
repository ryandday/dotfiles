return {
  -- Termdbg debugger with debug config manager
  {
    "epheien/termdbg",
    dir = vim.fn.stdpath("config") .. "/third_party/termdbg", -- Use local version from third_party
    dev = true, -- Mark as development plugin
    cmd = { "Termdbg" },
    keys = {
      { "<F5>", "<cmd>TContinue<cr>", desc = "Continue" },
      { "<F10>", "<cmd>TNext<cr>", desc = "Step Over" },
      { "<F11>", "<cmd>TStep<cr>", desc = "Step Into" },
      { "<S-F11>", "<cmd>TFinish<cr>", desc = "Step Out" },
      { "<F9>", "<cmd>TToggleBreak<cr>", desc = "Toggle Breakpoint" },
      { "<leader>dr", desc = "Run debug command (UI)" },
      { "<leader>dm", desc = "Manage debug commands (UI)" },
      { "<leader>da", desc = "Add debug command (UI)" },
    },
    config = function()
      -- Simple function to check if current buffer is a termdbg terminal
      local function is_debug_terminal(buf)
        buf = buf or vim.api.nvim_get_current_buf()
        local buf_name = vim.api.nvim_buf_get_name(buf)
        local buf_type = vim.api.nvim_buf_get_option(buf, "buftype")
        
        if buf_type == "terminal" then
          return buf_name:match("gdb") or buf_name:match("lldb") or buf_name:match("pdb") or 
                 buf_name:match("dlv") or buf_name:match("ipdb")
        end
        return false
      end

      -- Duct tape because ctrl+w is delete word backwards in a terminal, so you can't move to other windows.
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "*",
        callback = function()
          local buf = vim.api.nvim_get_current_buf()
          
          -- Wait a bit for the terminal name to be set properly
          vim.defer_fn(function()
            if is_debug_terminal(buf) then
              local opts = { buffer = buf, silent = true }
              
              -- Terminal navigation keymaps
              vim.keymap.set('t', '<C-w>', '<C-\\><C-n><C-w>', opts)
              vim.keymap.set('t', '<C-w>h', '<C-\\><C-n><C-w>h', opts)
              vim.keymap.set('t', '<C-w>j', '<C-\\><C-n><C-w>j', opts)
              vim.keymap.set('t', '<C-w>k', '<C-\\><C-n><C-w>k', opts)
              vim.keymap.set('t', '<C-w>l', '<C-\\><C-n><C-w>l', opts)
              vim.keymap.set('t', '<C-w>w', '<C-\\><C-n><C-w>w', opts)
              vim.keymap.set('t', '<C-w>p', '<C-\\><C-n><C-w>p', opts)
              vim.keymap.set('t', '<C-w>o', '<C-\\><C-n><C-w><C-w>', opts)
              
              -- Other useful terminal keymaps
              -- normal mode
              vim.keymap.set('t', '<C-o>', '<C-\\><C-n>', opts)
            end
          end, 100)
        end,
      })

      -- When entering a debug terminal, start in insert mode (for window switching)
      -- This is a workaround for termdbg's starting in normal mode 
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "*",
        callback = function()
          local buf = vim.api.nvim_get_current_buf()
          if is_debug_terminal(buf) then
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_get_current_buf() == buf then
                if vim.fn.mode() == 'n' then
                  vim.cmd('startinsert')
                end
              end
            end, 10)
          end
        end,
      })

      -- Setup debug commands manager
      local debug_manager = require("myplugins.debug-config-manager")
      debug_manager.setup()
    end,
  },
}