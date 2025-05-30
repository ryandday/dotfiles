return {
  -- Option 1: With luarocks.nvim (recommended for easier magick rock management)
  {
    "vhyrro/luarocks.nvim",
    priority = 1001, -- this plugin needs to run before anything else
    opts = {
      rocks = { "magick" },
    },
  },
  {
    "3rd/image.nvim",
    dependencies = { "luarocks.nvim" },
    config = function()
      require("image").setup({
        backend = "kitty",
        processor = "magick_rock", -- using magick rock since we have luarocks.nvim
        integrations = {
          markdown = {
            enabled = true,
            clear_in_insert_mode = false,
            download_remote_images = true,
            only_render_image_at_cursor = false,
            only_render_image_at_cursor_mode = "popup", -- "popup" or "inline"
            floating_windows = false,
            filetypes = { "markdown", "vimwiki" },
          },
          neorg = {
            enabled = true,
            filetypes = { "norg" },
          },
          typst = {
            enabled = true,
            filetypes = { "typst" },
          },
          html = {
            enabled = false,
          },
          css = {
            enabled = false,
          },
        },
        max_width = nil,
        max_height = nil,
        max_width_window_percentage = nil,
        max_height_window_percentage = 50,
        window_overlap_clear_enabled = false,
        window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "snacks_notif", "scrollview", "scrollview_sign" },
        editor_only_render_when_focused = false,
        tmux_show_only_in_active_window = false,
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
      })
    end,
  },

  -- Alternative Option 2: Without luarocks.nvim (if you prefer manual magick installation)
  -- Uncomment this and comment out the above if you want to install magick manually:
  --[[
  {
    "3rd/image.nvim",
    config = function()
      -- You'll need to install magick manually:
      -- luarocks --local --lua-version=5.1 install magick
      -- And add this to your config:
      -- package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?/init.lua"
      -- package.path = package.path .. ";" .. vim.fn.expand("$HOME") .. "/.luarocks/share/lua/5.1/?.lua"
      
      require("image").setup({
        backend = "kitty",
        processor = "magick_rock", -- or "magick_cli" if you only have ImageMagick CLI
        -- ... same config as above
      })
    end,
  },
  --]]
} 