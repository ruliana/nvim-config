return {
  {
    "local/bigquery-nvim",
    dir = vim.fn.stdpath("config") .. "/lua/bigquery",
    name = "bigquery.nvim",
    lazy = true,
    cmd = { "BQRun", "BQRunSelection", "BQPrompt", "BQFormat" },
    ft = { "sql", "bq" },
    keys = {
      { 
        "<leader>bq", 
        function()
          local mode = vim.api.nvim_get_mode().mode
          if mode == "v" or mode == "V" or mode == "" then
            vim.cmd("BQRunSelection")
          else
            vim.cmd("BQRun")
          end
        end,
        mode = { "n", "v" }, 
        desc = "Run BigQuery" 
      },
      { "<leader>bQ", "<cmd>BQPrompt<cr>", desc = "BigQuery Prompt" },
      { "<leader>bf", "<cmd>BQFormat<cr>", desc = "BigQuery Format" },
    },
    config = function()
      require("bigquery").setup({
        default_project = vim.env.GCP_PROJECT or vim.env.GOOGLE_CLOUD_PROJECT,
        max_results = 1000,
        format = "table",
        split_direction = "below",
        split_size = 15,
      })
    end,
  },
}