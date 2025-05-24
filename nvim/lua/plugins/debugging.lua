return {
  -- Debug Adapter Protocol
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      -- Creates a beautiful debugger UI
      "rcarriga/nvim-dap-ui",
      
      -- Required dependency for nvim-dap-ui
      "nvim-neotest/nvim-nio",
      
      -- Installs the debug adapters for you
      "williamboman/mason.nvim",
      "jay-babu/mason-nvim-dap.nvim",
      
      -- Add your own debuggers here
      "leoluz/nvim-dap-go",
    },
    keys = function(_, keys)
      local dap = require "dap"
      local dapui = require "dapui"
      return {
        -- Basic debugging keymaps
        { "<F5>", dap.continue, desc = "Debug: Start/Continue" },
        { "<F1>", dap.step_into, desc = "Debug: Step Into" },
        { "<F2>", dap.step_over, desc = "Debug: Step Over" },
        { "<F3>", dap.step_out, desc = "Debug: Step Out" },
        { "<leader>B", dap.toggle_breakpoint, desc = "Debug: Toggle Breakpoint" },
        -- { "<leader>B", function()
        --   dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
        end, desc = "Debug: Set Breakpoint" },
        
        -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
        { "<F7>", dapui.toggle, desc = "Debug: See last session result." },
        unpack(keys),
      }
    end,
    config = function()
      local dap = require "dap"
      local dapui = require "dapui"

      require("mason-nvim-dap").setup {
        -- Makes a best effort to setup the various debuggers with
        -- reasonable debug configurations
        automatic_installation = true,

        -- You can provide additional configuration to the handlers,
        -- see mason-nvim-dap README for more information
        handlers = {},

        -- You'll need to check that you have the required things installed
        -- online, please don't ask me how to install them :)
        ensure_installed = {
          -- Update this to ensure that you have the debuggers for the langs you want
          "codelldb",
        },
      }

      -- Dap UI setup
      -- For more information, see |:help nvim-dap-ui|
      dapui.setup {
        -- Set icons to characters that are more likely to work in every terminal.
        --    Feel free to remove or use ones that you like more! :)
        --    Don't feel like these are good choices.
        icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
        controls = {
          icons = {
            pause = "⏸",
            play = "▶",
            step_into = "⏎",
            step_over = "⏭",
            step_out = "⏮",
            step_back = "b",
            run_last = "▶▶",
            terminate = "⏹",
            disconnect = "⏏",
          },
        },
      }

      -- Change breakpoint icons
      vim.api.nvim_set_hl(0, 'DapBreakpoint', { ctermbg = 0, fg = '#993939', bg = '#31353f' })
      vim.api.nvim_set_hl(0, 'DapLogPoint', { ctermbg = 0, fg = '#61afef', bg = '#31353f' })
      vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 0, fg = '#98c379', bg = '#31353f' })

      vim.fn.sign_define('DapBreakpoint', { text='●', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl='DapBreakpoint' })
      vim.fn.sign_define('DapBreakpointCondition', { text='◆', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl='DapBreakpoint' })
      vim.fn.sign_define('DapBreakpointRejected', { text='▪', texthl='DapBreakpoint', linehl='DapBreakpoint', numhl='DapBreakpoint' })
      vim.fn.sign_define('DapLogPoint', { text='◆', texthl='DapLogPoint', linehl='DapLogPoint', numhl='DapLogPoint' })
      vim.fn.sign_define('DapStopped', { text='▶', texthl='DapStopped', linehl='DapStopped', numhl='DapStopped' })

      -- Automatically open UI
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -- C++ configuration
      dap.adapters.gdb = {
        type = "executable",
        command = "gdb",
        args = { "--interpreter=dap", "--eval-command", "set print pretty on" }
      }

      dap.adapters.lldb = {
        type = 'executable',
        command = '/usr/bin/lldb', -- adjust as needed, must be absolute path
        name = 'lldb'
      }

      -- C++ configurations
      dap.configurations.cpp = {
        {
          name = 'Launch',
          type = 'lldb',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          cwd = '${workspaceFolder}',
          stopOnEntry = false,
          args = {},
        },
        {
          name = 'Launch with GDB',
          type = 'gdb',
          request = 'launch',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          cwd = "${workspaceFolder}",
          stopAtBeginningOfMainSubprogram = false,
        },
        {
          name = 'Attach to gdbserver :1234',
          type = 'gdb',
          request = 'attach',
          target = 'localhost:1234',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          cwd = '${workspaceFolder}'
        },
      }

      -- If you want to use this for Rust and C, add something like this:
      dap.configurations.c = dap.configurations.cpp
      dap.configurations.rust = dap.configurations.cpp
    end,
  },
} 