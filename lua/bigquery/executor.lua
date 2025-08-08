local M = {}

local function build_command(query, config)
  local cmd = { config.bq_command, "query" }
  
  -- Add format flag
  if config.format == "json" then
    table.insert(cmd, "--format=prettyjson")
  elseif config.format == "csv" then
    table.insert(cmd, "--format=csv")
  else
    table.insert(cmd, "--format=pretty")
  end
  
  -- Add max rows
  table.insert(cmd, "--max_rows=" .. config.max_results)
  
  -- Add project if specified
  if config.default_project then
    table.insert(cmd, "--project_id=" .. config.default_project)
  end
  
  -- Add legacy SQL flag if needed
  if config.use_legacy_sql then
    table.insert(cmd, "--use_legacy_sql=true")
  else
    table.insert(cmd, "--use_legacy_sql=false")
  end
  
  -- Don't add query to command, we'll use stdin instead
  
  return cmd
end

function M.execute(query, config)
  local display = require("bigquery.display")
  
  -- Show notification that query is running
  vim.notify("Running BigQuery query...", vim.log.levels.INFO)
  
  local cmd = build_command(query, config)
  
  -- Debug: print the command
  vim.notify("Command: " .. table.concat(cmd, " "), vim.log.levels.DEBUG)
  local output_lines = {}
  local error_lines = {}
  local start_time = vim.loop.now()
  
  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(output_lines, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          -- Filter out progress messages from bq command
          if line ~= "" and not line:match("^Waiting on bqjob") and not line:match("Current status:") then
            table.insert(error_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        local elapsed = (vim.loop.now() - start_time) / 1000
        
        if exit_code == 0 then
          if #output_lines > 0 then
            display.show_results(output_lines, config, query, elapsed)
          else
            vim.notify("Query returned no results", vim.log.levels.INFO)
          end
        else
          M.handle_error(error_lines, query)
        end
      end)
    end,
  })
  
  if job_id == 0 then
    vim.notify("Failed to start BigQuery command", vim.log.levels.ERROR)
  elseif job_id == -1 then
    vim.notify("BigQuery command is not executable", vim.log.levels.ERROR)
  else
    -- Send the query via stdin
    vim.fn.chansend(job_id, query)
    vim.fn.chanclose(job_id, "stdin")
  end
  
  return job_id
end

function M.handle_error(error_lines, query)
  local error_msg = table.concat(error_lines, "\n")
  
  -- Parse common BigQuery errors
  if error_msg:match("Not found") then
    vim.notify("BigQuery Error: Table or dataset not found", vim.log.levels.ERROR)
  elseif error_msg:match("Syntax error") then
    vim.notify("BigQuery Syntax Error - check the error buffer for details", vim.log.levels.ERROR)
  elseif error_msg:match("Permission denied") or error_msg:match("Access Denied") then
    vim.notify("BigQuery Permission Error: Check your credentials", vim.log.levels.ERROR)
  elseif error_msg:match("Exceeded quota") then
    vim.notify("BigQuery Quota Exceeded", vim.log.levels.ERROR)
  else
    vim.notify("BigQuery Error - check the error buffer for details", vim.log.levels.ERROR)
  end
  
  -- Show detailed error in a buffer
  local display = require("bigquery.display")
  display.show_error(error_lines, query)
end

return M