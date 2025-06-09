-- Terminal management functions and state
local terminal_state = {
  current = 1,
  max = 1,
  direction = "float" -- Default direction
}

local function setup()
  -- Any setup logic if needed
end

local function new_terminal()
  terminal_state.max = terminal_state.max + 1
  terminal_state.current = terminal_state.max
  vim.cmd(terminal_state.max .. "ToggleTerm direction=" .. terminal_state.direction)
  
  -- Wait for terminal to be ready before entering insert mode
  vim.defer_fn(function()
    if vim.bo.filetype == "toggleterm" then
      vim.cmd("startinsert!")
    end
  end, 10)
  
  vim.notify("Created terminal " .. terminal_state.max, vim.log.levels.INFO)
end

local function next_terminal()
  if terminal_state.current < terminal_state.max then
    terminal_state.current = terminal_state.current + 1
  else
    terminal_state.current = 1
  end
  vim.cmd(terminal_state.current .. "ToggleTerm direction=" .. terminal_state.direction)
  vim.notify("Switched to terminal " .. terminal_state.current, vim.log.levels.INFO)
end

local function prev_terminal()
  if terminal_state.current > 1 then
    terminal_state.current = terminal_state.current - 1
  else
    terminal_state.current = terminal_state.max
  end
  vim.cmd(terminal_state.current .. "ToggleTerm direction=" .. terminal_state.direction)
  vim.notify("Switched to terminal " .. terminal_state.current, vim.log.levels.INFO)
end

local function list_terminals()
  local terminals = {}
  for i = 1, terminal_state.max do
    local indicator = (i == terminal_state.current) and " (current)" or ""
    table.insert(terminals, "Terminal " .. i .. indicator)
  end
  
  vim.notify("Active terminals:\n" .. table.concat(terminals, "\n"), vim.log.levels.INFO)
end

local function toggle_current_terminal()
  -- If no terminals exist yet, create the first one
  if terminal_state.max == 0 then
    terminal_state.max = 1
    terminal_state.current = 1
  end
  
  vim.cmd(terminal_state.current .. "ToggleTerm direction=" .. terminal_state.direction)
  
  -- If we're entering the terminal, go to insert mode
  vim.defer_fn(function()
    if vim.bo.filetype == "toggleterm" then
      vim.cmd("startinsert!")
    end
  end, 10)
end

-- Export functions for external use
_G.terminal_funcs = {
  setup = setup,
  new_terminal = new_terminal,
  next_terminal = next_terminal,
  prev_terminal = prev_terminal,
  list_terminals = list_terminals,
  toggle_current_terminal = toggle_current_terminal,
}

return {
  -- Better terminal integration
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm direction=float<cr>", desc = "Toggle Terminal (Float)" },
      { "<leader>tv", function() _G.terminal_funcs.list_terminals() end, desc = "List Terminals" },
      { "<C-\\>", function() _G.terminal_funcs.toggle_current_terminal() end, desc = "Toggle Current Terminal", mode = {"n", "t"} },
    },
    config = function()
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then
            return 15
          elseif term.direction == "vertical" then
            return vim.o.columns * 0.4
          end
        end,
        open_mapping = nil, -- We'll handle this ourselves
        hide_numbers = true,
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = "float",
        close_on_exit = false,
        shell = vim.o.shell,
        float_opts = {
          border = "curved",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal",
          },
        },
        on_open = function(term)
          local opts = {buffer = term.bufnr}
          vim.keymap.set('t', '<C-o>', [[<C-\><C-n>]], opts)
          
          -- Terminal navigation mappings (work while in terminal mode)
          vim.keymap.set('t', '<C-t>', function() _G.terminal_funcs.new_terminal() end, opts)
          vim.keymap.set('t', '<C-]>', function() _G.terminal_funcs.next_terminal() end, opts)
          vim.keymap.set('t', '<C-[>', function() _G.terminal_funcs.prev_terminal() end, opts)
        end,
      })
      
      -- Initialize terminal management
      _G.terminal_funcs.setup()
    end,
  },
}
