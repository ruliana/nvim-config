return {
  {
    "local/bigquery-nvim",
    dir = vim.fn.stdpath("config") .. "/lua/bigquery",
    name = "bigquery.nvim",
    lazy = true,
    dependencies = {
      "hrsh7th/nvim-cmp",
      "nvim-telescope/telescope.nvim",
    },
    cmd = { 
      "BQRun", 
      "BQRunSelection", 
      "BQPrompt", 
      "BQFormat",
      "BQBrowseTables",
      "BQPinTable",
      "BQUnpinTable",
      "BQClearCache",
      "BQShowCache",
      "BQCreateConfig",
      "BQDiscoverUsage",
      "BQDiscoverTables",
      "BQValidate",
      "BQValidateSelection"
    },
    ft = { "sql", "bq", "bigquery" },
    keys = {
      { 
        "<leader>bq", 
        function()
          local mode = vim.api.nvim_get_mode().mode
          if mode == "v" or mode == "V" or mode == "" then
            -- Get the actual visual selection range
            local vstart = vim.fn.line('v')
            local vend = vim.fn.line('.')
            local start_line = math.min(vstart, vend)
            local end_line = math.max(vstart, vend)
            -- Pass the range explicitly to the command
            vim.cmd(string.format("%d,%dBQRunSelection", start_line, end_line))
          else
            vim.cmd("BQRun")
          end
        end,
        mode = { "n", "v" }, 
        desc = "Run BigQuery (cursor query or selection)" 
      },
      { "<leader>bQ", "<cmd>BQPrompt<cr>", desc = "BigQuery Prompt" },
      { "<leader>bf", "<cmd>BQFormat<cr>", desc = "BigQuery Format" },
      { "<leader>bt", "<cmd>BQBrowseTables<cr>", desc = "Browse BigQuery tables" },
      { "<leader>bp", "<cmd>BQPinTable<cr>", desc = "Pin current table" },
      { "<leader>bc", "<cmd>BQClearCache<cr>", desc = "Clear BigQuery cache" },
      { "<leader>bd", "<cmd>BQDiscoverUsage<cr>", desc = "Discover BigQuery usage patterns" },
      { 
        "<leader>bv", 
        function()
          local mode = vim.api.nvim_get_mode().mode
          if mode == "v" or mode == "V" or mode == "" then
            -- Get the actual visual selection range
            local vstart = vim.fn.line('v')
            local vend = vim.fn.line('.')
            local start_line = math.min(vstart, vend)
            local end_line = math.max(vstart, vend)
            -- Pass the range explicitly to the command
            vim.cmd(string.format("%d,%dBQValidateSelection", start_line, end_line))
          else
            vim.cmd("BQValidate")
          end
        end,
        mode = { "n", "v" }, 
        desc = "Validate BigQuery query" 
      },
    },
    config = function()
      require("bigquery").setup({
        default_project = vim.env.GCP_PROJECT or vim.env.GOOGLE_CLOUD_PROJECT,
        max_results = 1000,
        format = "table",
        split_direction = "below",
        split_size = 15,
      })
      
      -- Register the BigQuery completion source
      local cmp = require('cmp')
      local bq_source = require('bigquery.cmp_source')
      cmp.register_source('bigquery', bq_source.new())
      
      -- Add BigQuery source to existing cmp config for SQL files
      local config = cmp.get_config()
      table.insert(config.sources, {
        name = 'bigquery',
        priority = 800,
        group_index = 1
      })
      cmp.setup(config)
    end,
  },
}