return {
  {
    "echasnovski/mini.operators",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("mini.operators").setup()
    end,
  },
}