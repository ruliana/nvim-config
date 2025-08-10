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
  
  
  local cmd = build_command(query, config)
  
  -- Initialize timing
  local start_time = vim.loop.now()
  local output_lines = {}
  local error_lines = {}
  
  -- Progress indicator
  local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
  local spinner_idx = 1
  local progress_timer = nil
  local job_running = true
  
  -- Function to update progress
  local function update_progress()
    if job_running then
      local elapsed = math.floor((vim.loop.now() - start_time) / 1000)
      local spinner = spinner_frames[spinner_idx]
      spinner_idx = (spinner_idx % #spinner_frames) + 1
      
      -- Set global variable for statusline
      vim.g.bigquery_status = string.format("%s BigQuery running... (%ds)", spinner, elapsed)
      
      -- Force statusline redraw
      vim.cmd('redrawstatus')
    end
  end
  
  -- Start progress indicator
  progress_timer = vim.loop.new_timer()
  progress_timer:start(0, 100, vim.schedule_wrap(update_progress))
  
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
          -- Filter out progress messages from bq command, but keep DDL success messages
          if line ~= "" and not line:match("^Waiting on bqjob") and not line:match("Current status:") then
            table.insert(error_lines, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        -- Stop the progress indicator
        job_running = false
        if progress_timer then
          progress_timer:stop()
          progress_timer:close()
        end
        
        -- Clear the status from statusline
        vim.g.bigquery_status = nil
        vim.cmd('redrawstatus')
        
        local elapsed = (vim.loop.now() - start_time) / 1000
        
        
        if exit_code == 0 then
          -- Check for DDL statements that might have simple output
          local is_ddl = query:lower():match("^%s*drop%s+") or 
                        query:lower():match("^%s*create%s+") or
                        query:lower():match("^%s*alter%s+") or
                        query:lower():match("^%s*truncate%s+")
          
          
          if #output_lines > 0 then
            -- Check if output is a DDL success message
            local is_ddl_success = false
            local ddl_message = nil
            
            if is_ddl and #output_lines == 1 then
              local line = output_lines[1]
              if line:match("^Dropped ") or line:match("^Created ") or 
                 line:match("^Altered ") or line:match("^Truncated ") then
                is_ddl_success = true
                ddl_message = line
              end
            end
            
            if is_ddl_success then
              -- Show simple notification for DDL success
              vim.notify(ddl_message .. string.format(" (%.2fs)", elapsed), vim.log.levels.INFO)
            else
              -- Show normal results window for SELECT queries
              display.show_results(output_lines, config, query, elapsed)
            end
            
            -- Track table usage in MRU
            local tables = {}
            -- Extract tables from query
            for match in query:gmatch('`([^`]+%.[^`]+%.[^`]+)`') do
              table.insert(tables, match)
            end
            for match in query:gmatch('`([^`]+%.[^`]+)`') do
              -- Add default project if needed
              local workspace = require("bigquery.workspace")
              local default_project = workspace.get_default_project()
              if default_project and not match:match('%..*%.') then
                match = default_project .. '.' .. match
              end
              table.insert(tables, match)
            end
            
            if #tables > 0 then
              local mru = require("bigquery.mru")
              for _, table_ref in ipairs(tables) do
                mru.add(table_ref)
              end
            end
          else
            vim.notify("Query returned no results", vim.log.levels.INFO)
          end
        else
          
          -- Check if error came through stdout instead of stderr
          local actual_error_lines = error_lines
          if #error_lines == 0 and #output_lines > 0 then
            -- Check if stdout contains error messages
            local has_error = false
            for _, line in ipairs(output_lines) do
              if line:match("^Error") or line:match("error:") or line:match("Syntax error") then
                has_error = true
                break
              end
            end
            
            if has_error then
              -- Use stdout as error lines since that's where BigQuery sent the error
              actual_error_lines = output_lines
            end
          end
          
          M.handle_error(actual_error_lines, query)
        end
        
      end)
    end,
  })
  
  if job_id == 0 then
    job_running = false
    if progress_timer then
      progress_timer:stop()
      progress_timer:close()
    end
    vim.g.bigquery_status = nil
    vim.cmd('redrawstatus')
    vim.notify("Failed to start BigQuery command", vim.log.levels.ERROR)
  elseif job_id == -1 then
    job_running = false
    if progress_timer then
      progress_timer:stop()
      progress_timer:close()
    end
    vim.g.bigquery_status = nil
    vim.cmd('redrawstatus')
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