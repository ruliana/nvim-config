return {
  {
    "folke/flash.nvim",
    -- dir = "/Users/ronie/code/nvim/flash.nvim", -- Use your local development version
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      -- Your original labels as fallback (for backward compatibility)
      labels = "soaeiultcpwvgfzq",
      
      -- NEW: Directional labeling configuration
      labels_ahead = "dsrn",      -- Labels for matches ahead of cursor (after cursor position)
      labels_behind = "oaei",     -- Labels for matches behind cursor (before cursor position)
      
      label = {
        distance = true,
      },
      
      -- Optional: Make it more visible for testing
      highlight = {
        backdrop = true,
      },
      
      -- Enable search integration for n/N repeat
      search = {
        multi_window = true,
        forward = true,
        wrap = true,
      },
      
      -- Enable search mode for / and ? integration with n/N repeat
      modes = {
        search = {
          enabled = true,
          highlight = { backdrop = false },
          jump = { 
            history = true, 
            register = true, 
            nohlsearch = true 
          },
        },
      },
    },
    keys = {
      { "?", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      winopts = {
        height = 0.85,
        width = 0.80,
        row = 0.35,
        col = 0.50,
        border = "rounded",
        preview = {
          border = "border",
          wrap = "nowrap",
          hidden = "nohidden",
          vertical = "down:45%",
          horizontal = "right:60%",
          layout = "flex",
          flip_columns = 120,
        },
      },
      keymap = {
        builtin = {
          ["<F1>"] = "toggle-help",
          ["<F2>"] = "toggle-fullscreen",
          ["<F3>"] = "toggle-preview-wrap",
          ["<F4>"] = "toggle-preview",
          ["<C-d>"] = "preview-page-down",
          ["<C-u>"] = "preview-page-up",
        },
        fzf = {
          ["ctrl-z"] = "abort",
          ["ctrl-u"] = "unix-line-discard",
          ["ctrl-f"] = "half-page-down",
          ["ctrl-b"] = "half-page-up",
          ["ctrl-a"] = "beginning-of-line",
          ["ctrl-e"] = "end-of-line",
          ["alt-a"] = "toggle-all",
          ["f3"] = "toggle-preview-wrap",
          ["f4"] = "toggle-preview",
          ["shift-down"] = "preview-page-down",
          ["shift-up"] = "preview-page-up",
        },
      },
      files = {
        prompt = "Files❯ ",
        multiprocess = true,
        git_icons = true,
        file_icons = true,
        color_icons = true,
      },
      grep = {
        prompt = "Rg❯ ",
        input_prompt = "Grep For❯ ",
        multiprocess = true,
        git_icons = true,
        file_icons = true,
        color_icons = true,
      },
      buffers = {
        prompt = "Buffers❯ ",
        file_icons = true,
        color_icons = true,
      },
      oldfiles = {
        prompt = "History❯ ",
        cwd_only = false,
      },
    },
  },
}