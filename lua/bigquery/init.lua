local M = {}

M.config = nil

function M.setup(opts)
  M.config = require("bigquery.config").setup(opts)
  
  -- Initialize workspace config
  require("bigquery.workspace").load()
  
  -- Create commands
  vim.api.nvim_create_user_command("BQRun", function()
    M.run_query()
  end, { desc = "Run BigQuery query from current buffer" })
  
  vim.api.nvim_create_user_command("BQRunSelection", function(opts)
    M.run_selection(opts.line1, opts.line2)
  end, { range = true, desc = "Run selected BigQuery query" })
  
  vim.api.nvim_create_user_command("BQPrompt", function()
    M.run_prompt()
  end, { desc = "Run BigQuery query from prompt" })
  
  vim.api.nvim_create_user_command("BQFormat", function()
    M.cycle_format()
  end, { desc = "Cycle through BigQuery result formats" })
  
  -- New commands for autocomplete features
  vim.api.nvim_create_user_command("BQBrowseTables", function()
    require("bigquery.browser").browse_tables()
  end, { desc = "Browse BigQuery tables with fuzzy finder" })
  
  vim.api.nvim_create_user_command("BQPinTable", function(opts)
    local table_ref = opts.args
    if table_ref == '' then
      table_ref = require("bigquery.input").get_table_under_cursor()
    end
    if table_ref then
      local workspace = require("bigquery.workspace")
      if workspace.pin_table(table_ref) then
        vim.notify("Pinned table: " .. table_ref, vim.log.levels.INFO)
      else
        vim.notify("Table already pinned: " .. table_ref, vim.log.levels.WARN)
      end
    else
      vim.notify("No table reference found", vim.log.levels.ERROR)
    end
  end, { nargs = '?', desc = "Pin table for quick access" })
  
  vim.api.nvim_create_user_command("BQUnpinTable", function(opts)
    local table_ref = opts.args
    if table_ref == '' then
      table_ref = require("bigquery.input").get_table_under_cursor()
    end
    if table_ref then
      local workspace = require("bigquery.workspace")
      if workspace.unpin_table(table_ref) then
        vim.notify("Unpinned table: " .. table_ref, vim.log.levels.INFO)
      else
        vim.notify("Table not pinned: " .. table_ref, vim.log.levels.WARN)
      end
    else
      vim.notify("No table reference found", vim.log.levels.ERROR)
    end
  end, { nargs = '?', desc = "Unpin table from quick access" })
  
  vim.api.nvim_create_user_command("BQClearCache", function()
    require("bigquery.cache").clear_all()
    vim.notify("BigQuery cache cleared", vim.log.levels.INFO)
  end, { desc = "Clear BigQuery metadata cache" })
  
  vim.api.nvim_create_user_command("BQShowCache", function()
    local stats = require("bigquery.cache").get_stats()
    vim.notify(string.format("Cache: %d projects, %d datasets, %d tables, %d schemas",
      stats.projects, stats.datasets, stats.tables, stats.schemas), vim.log.levels.INFO)
  end, { desc = "Show BigQuery cache statistics" })
  
  vim.api.nvim_create_user_command("BQCreateConfig", function()
    if require("bigquery.workspace").create_sample_config() then
      vim.notify("Created .bqrc.json config file", vim.log.levels.INFO)
    else
      vim.notify("Failed to create config file", vim.log.levels.ERROR)
    end
  end, { desc = "Create sample BigQuery workspace config" })
end

function M.run_query()
  local input = require("bigquery.input")
  local executor = require("bigquery.executor")
  
  local query = input.get_buffer_query()
  if not query or query == "" then
    vim.notify("No query found in buffer", vim.log.levels.WARN)
    return
  end
  
  executor.execute(query, M.config)
end

function M.run_selection(line1, line2)
  local input = require("bigquery.input")
  local executor = require("bigquery.executor")
  
  local query
  if line1 and line2 then
    -- Get lines from range
    local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    query = table.concat(lines, "\n")
  else
    -- Fall back to visual selection
    query = input.get_visual_selection()
  end
  
  if not query or query == "" then
    vim.notify("No query selected", vim.log.levels.WARN)
    return
  end
  
  executor.execute(query, M.config)
end

function M.run_prompt()
  local input = require("bigquery.input")
  local executor = require("bigquery.executor")
  
  local query = input.prompt_for_query()
  if not query or query == "" then
    return
  end
  
  executor.execute(query, M.config)
end

function M.cycle_format()
  local formats = { "table", "json", "csv" }
  local current_idx = 1
  
  for i, format in ipairs(formats) do
    if format == M.config.format then
      current_idx = i
      break
    end
  end
  
  local next_idx = (current_idx % #formats) + 1
  M.config.format = formats[next_idx]
  
  vim.notify("BigQuery format: " .. M.config.format, vim.log.levels.INFO)
end

return M