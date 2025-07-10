return {
  {
    "folke/which-key.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer Local Keymaps (which-key)",
      },
    },
    config = function()
      require("which-key").add({
        { "<leader>m", group = "Markdown" },
        { "<leader>c", group = "Compile" },
        { "<leader>t", group = "Table" },
      })
    end,
  },
  {
    "echasnovski/mini.operators",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("mini.operators").setup()
    end,
  },
  {
    "echasnovski/mini.indentscope",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("mini.indentscope").setup()
    end,
  },
  {
    "lewis6991/spaceless.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("spaceless").setup()
    end,
  },
}