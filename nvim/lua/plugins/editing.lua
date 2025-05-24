return {
  -- Surround text objects
  {
    "tpope/vim-surround",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Text case conversion and substitution
  {
    "tpope/vim-abolish",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Smart commenting
  {
    "tpope/vim-commentary",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Repeat plugin commands with .
  {
    "tpope/vim-repeat",
    event = { "BufReadPre", "BufNewFile" },
  },

  -- Async command execution
  {
    "tpope/vim-dispatch",
    cmd = { "Dispatch", "Make", "Focus", "Start" },
  },
} 