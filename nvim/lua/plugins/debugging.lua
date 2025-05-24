return {
  -- Terminal debugger (for lldb)
  {
    "epheien/termdbg",
    cmd = { "Termdebug", "TermdebugCommand" },
    config = function()
      -- Keep your existing termdbg settings
      vim.g.termdebug_wide = 1
    end,
  },
} 