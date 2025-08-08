local M = {}

M.config = nil

function M.setup(opts)
  M.config = require("bigquery.config").setup(opts)
  
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