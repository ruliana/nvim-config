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
        { "<leader>d", group = "Debug" },
        { "<leader>f", group = "Find" },
        { "<leader>g", group = "Git" },
      })
    end,
  },
  {
    "echasnovski/mini.indentscope",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("mini.indentscope").setup()
    end,
  },
}