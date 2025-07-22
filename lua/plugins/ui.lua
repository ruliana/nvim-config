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
        { "<leader>g", group = "Git" },
        { "<leader>gt", function() require("agitator").git_time_machine() end, desc = "Git Time Travel" },
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