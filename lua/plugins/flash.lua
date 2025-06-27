return {
  "folke/flash.nvim",
  dir = "/Users/ronie/code/nvim/flash.nvim", -- Use your local development version
  event = "VeryLazy",
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
  },
  keys = {
    { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
    { "r", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
  },
}
