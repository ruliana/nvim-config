local M = {}

M.defaults = {
  default_project = nil,
  default_dataset = nil,
  max_results = 1000,
  format = "table", -- table, json, csv
  split_direction = "below", -- below, above, left, right
  split_size = 15,
  bq_command = "bq",
  use_legacy_sql = false,
  show_query_time = true,
  auto_format = true, -- automatically format JSON results
}

function M.setup(opts)
  local config = vim.tbl_deep_extend("force", M.defaults, opts or {})
  
  -- Validate configuration
  if not vim.fn.executable(config.bq_command) then
    vim.notify("BigQuery CLI not found: " .. config.bq_command, vim.log.levels.ERROR)
    vim.notify("Please install gcloud SDK and authenticate", vim.log.levels.ERROR)
  end
  
  -- Set default project from environment or gcloud config if not provided
  if not config.default_project then
    config.default_project = vim.env.GCP_PROJECT or vim.env.GOOGLE_CLOUD_PROJECT
    
    -- If still no project, try to get from gcloud config
    if not config.default_project then
      local handle = io.popen("gcloud config get-value project 2>/dev/null")
      if handle then
        local result = handle:read("*a")
        handle:close()
        result = result:gsub("%s+", "") -- trim whitespace
        if result ~= "" then
          config.default_project = result
        end
      end
    end
    
    if config.default_project then
      vim.notify("Using GCP project: " .. config.default_project, vim.log.levels.INFO)
    end
  end
  
  return config
end

return M