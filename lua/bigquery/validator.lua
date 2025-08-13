local M = {}

local validation_win = nil
local validation_buf = nil

local function format_bytes(bytes)
   if not bytes then return "0 B" end
   
   local units = {"B", "KB", "MB", "GB", "TB"}
   local idx = 1
   local size = tonumber(bytes)
   
   while size >= 1024 and idx < #units do
      size = size / 1024
      idx = idx + 1
   end
   
   if idx == 1 then
      return string.format("%d %s", size, units[idx])
   else
      return string.format("%.2f %s", size, units[idx])
   end
end

local function create_float_window(content, is_error, is_cached)
   -- Close existing window if any
   M.close_validation_window()
   
   -- Get current window dimensions
   local win_width = vim.api.nvim_win_get_width(0)
   local win_height = vim.api.nvim_win_get_height(0)
   
   -- Calculate window size and position
   local float_width = math.min(50, math.floor(win_width * 0.4))
   local float_height = #content + 2  -- Content lines + padding
   
   -- Position at top-right corner with some padding
   local row = 1
   local col = win_width - float_width - 2
   
   -- Create buffer for content
   validation_buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_lines(validation_buf, 0, -1, false, content)
   
   -- Set buffer options
   vim.api.nvim_buf_set_option(validation_buf, 'bufhidden', 'wipe')
   vim.api.nvim_buf_set_option(validation_buf, 'modifiable', false)
   
   -- Window configuration
   local title = is_error and ' Syntax Error ' or ' Query Validation '
   if is_cached then
      title = '✓ ' .. title
   end
   
   local win_config = {
      relative = 'win',
      row = row,
      col = col,
      width = float_width,
      height = float_height,
      style = 'minimal',
      border = 'rounded',
      title = title,
      title_pos = 'center',
   }
   
   -- Create the floating window
   validation_win = vim.api.nvim_open_win(validation_buf, false, win_config)
   
   -- Set window highlight
   if is_error then
      vim.api.nvim_win_set_option(validation_win, 'winhl', 'Normal:ErrorFloat,FloatBorder:ErrorFloat')
   else
      vim.api.nvim_win_set_option(validation_win, 'winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder')
   end
   
   -- Window will be closed by autocmd on cursor move, not by timer
end

function M.close_validation_window()
   if validation_win and vim.api.nvim_win_is_valid(validation_win) then
      vim.api.nvim_win_close(validation_win, true)
   end
   validation_win = nil
   validation_buf = nil
end

function M.validate_query(query)
   if not query or query == "" then
      return
   end
   
   -- Get the default project from config
   local bigquery = require("bigquery")
   local config = bigquery.config
   local project = config and config.default_project
   
   if not project then
      vim.notify("No default project configured", vim.log.levels.ERROR)
      return
   end
   
   -- Get cache module and generate hash
   local cache = require("bigquery.cache")
   local query_hash = cache.hash_query(query)
   
   -- Check cache first
   local cached_result = cache.get_validation(query_hash)
   if cached_result then
      -- Use cached result
      if cached_result.error then
         -- Split error message for display
         local lines = {}
         local max_width = 45
         for line in cached_result.error:gmatch("[^\n]+") do
            if #line > max_width then
               -- Word wrap long lines
               local current = ""
               for word in line:gmatch("%S+") do
                  if #current + #word + 1 > max_width then
                     if #current > 0 then
                        table.insert(lines, current)
                     end
                     current = word
                  else
                     current = current .. (current == "" and "" or " ") .. word
                  end
               end
               if #current > 0 then
                  table.insert(lines, current)
               end
            else
               table.insert(lines, line)
            end
         end
         create_float_window(lines, true, true)  -- true for is_cached
      else
         local bytes_msg = cached_result.bytes_processed and 
            ("Bytes to process: " .. format_bytes(cached_result.bytes_processed)) or 
            "Query validated successfully"
         create_float_window({bytes_msg}, false, true)  -- true for is_cached
      end
      return
   end
   
   -- Not in cache, run validation in background
   -- Create temporary file for the query
   local tmpfile = vim.fn.tempname() .. ".sql"
   local f = io.open(tmpfile, "w")
   if not f then
      vim.notify("Failed to create temp file", vim.log.levels.ERROR)
      return
   end
   f:write(query)
   f:close()
   
   -- Build the bq command with dry_run
   local cmd = {
      "bq", "query",
      "--project_id=" .. project,
      "--use_legacy_sql=false",
      "--dry_run",
      "--format=json"
   }
   
   -- Accumulate output
   local output_lines = {}
   local stderr_lines = {}
   
   -- Start the job
   local job_id = vim.fn.jobstart(cmd, {
      stdin = "pipe",
      on_stdout = function(_, data, _)
         if data then
            for _, line in ipairs(data) do
               if line ~= "" then
                  table.insert(output_lines, line)
               end
            end
         end
      end,
      on_stderr = function(_, data, _)
         if data then
            for _, line in ipairs(data) do
               if line ~= "" then
                  table.insert(stderr_lines, line)
               end
            end
         end
      end,
      on_exit = function(_, exit_code, _)
         -- Clean up temp file
         vim.fn.delete(tmpfile)
         
         -- Combine output
         local output = table.concat(output_lines, "\n")
         local stderr = table.concat(stderr_lines, "\n")
         
         -- Prepare cache result
         local cache_result = {}
         
         -- Check for actual errors (not just the word "Error" in field names or data)
         local has_error = exit_code ~= 0 or 
                          output:match("^Error") or 
                          output:match("\nError") or
                          output:match("^FATAL") or
                          output:match("\nFATAL") or
                          stderr:match("Error") or
                          stderr:match("FATAL")
         
         if has_error then
            -- Extract error message from stdout (where bq sends errors)
            local error_msg = nil
            
            -- Try to find error in output (stdout) - look for actual error patterns
            if output and output ~= "" then
               -- Look for the full error message including "Error in query string:" part
               error_msg = output:match("Error in query string:%s*(.+)") or
                          output:match("^Error:%s*(.+)") or
                          output:match("\nError:%s*(.+)") or
                          output:match("^FATAL:%s*(.+)") or
                          output:match("\nFATAL:%s*(.+)") or
                          output:match("^Invalid:%s*(.+)") or
                          output:match("\nInvalid:%s*(.+)")
            end
            
            -- Fallback to stderr if error is there
            if (not error_msg or error_msg == "") and stderr and stderr ~= "" then
               error_msg = stderr:match("Error[^\n]*:%s*(.+)") or
                          stderr:match("FATAL[^\n]*:%s*(.+)") or
                          stderr:match("Invalid[^\n]*:%s*(.+)")
               
               -- If still no match but stderr has content, use it
               if not error_msg and exit_code ~= 0 then
                  local trimmed = stderr:gsub("^%s+", ""):gsub("%s+$", "")
                  if trimmed ~= "" then
                     error_msg = trimmed
                  end
               end
            end
            
            -- Final fallback only if we really have an error
            if not error_msg or error_msg == "" then
               if exit_code ~= 0 then
                  error_msg = "Validation failed (exit code: " .. tostring(exit_code) .. ")"
               else
                  -- Skip this as false positive - probably "Error" in field name
                  has_error = false
               end
            else
               -- Clean up error message
               error_msg = error_msg:gsub("^%s+", ""):gsub("%s+$", "")
            end
            
            if has_error and error_msg then
               -- Store error in cache
               cache_result.error = error_msg
               
               -- Split long error messages into multiple lines for display
               local lines = {}
               local max_width = 45
               for line in error_msg:gmatch("[^\n]+") do
                  if #line > max_width then
                     -- Word wrap long lines
                     local current = ""
                     for word in line:gmatch("%S+") do
                        if #current + #word + 1 > max_width then
                           if #current > 0 then
                              table.insert(lines, current)
                           end
                           current = word
                        else
                           current = current .. (current == "" and "" or " ") .. word
                        end
                     end
                     if #current > 0 then
                        table.insert(lines, current)
                     end
                  else
                     table.insert(lines, line)
                  end
               end
               
               create_float_window(lines, true, false)  -- false for not cached
            end
         else
            -- Try to parse JSON output for bytes processed
            local ok, json = pcall(vim.json.decode, output)
            local bytes_msg = "Query validated successfully"
            
            if ok and json and json.statistics and json.statistics.query then
               local bytes = json.statistics.query.totalBytesProcessed
               if bytes then
                  cache_result.bytes_processed = tonumber(bytes)
                  bytes_msg = "Bytes to process: " .. format_bytes(bytes)
               end
            elseif output:match("totalBytesProcessed") then
               -- Fallback: try to extract bytes from raw output
               local bytes = output:match('"totalBytesProcessed"%s*:%s*"?(%d+)"?')
               if bytes then
                  cache_result.bytes_processed = tonumber(bytes)
                  bytes_msg = "Bytes to process: " .. format_bytes(bytes)
               end
            end
            
            create_float_window({bytes_msg}, false, false)  -- false for not cached
         end
         
         -- Store result in cache
         cache.set_validation(query_hash, cache_result)
      end
   })
   
   -- Send the query to stdin
   if job_id > 0 then
      -- Read the file and send to stdin
      local file_content = vim.fn.readfile(tmpfile)
      if file_content and #file_content > 0 then
         vim.fn.chansend(job_id, file_content)
      end
      vim.fn.chanclose(job_id, "stdin")
   else
      vim.notify("Failed to start validation job", vim.log.levels.ERROR)
      vim.fn.delete(tmpfile)
   end
end

function M.validate_current_query()
   local input = require("bigquery.input")
   
   -- Try to get query at cursor position first
   local query = input.get_query_at_cursor()
   if not query or query == "" then
      -- Fall back to getting the entire buffer
      query = input.get_buffer_query()
      if not query or query == "" then
         vim.notify("No query found", vim.log.levels.WARN)
         return
      end
   end
   
   M.validate_query(query)
end

function M.validate_selection(line1, line2)
   local input = require("bigquery.input")
   
   local query
   if line1 and line2 then
      -- Get lines from range
      local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
      
      -- Check if all non-empty lines start with '--'
      local all_commented = true
      for _, line in ipairs(lines) do
         if not line:match("^%s*$") then
            if not line:match("^%s*%-%-") then
               all_commented = false
               break
            end
         end
      end
      
      -- If all non-empty lines are commented, remove the comment prefix
      if all_commented then
         for i, line in ipairs(lines) do
            if not line:match("^%s*$") then
               lines[i] = line:gsub("^(%s*)%-%-%s?", "%1")
            end
         end
      end
      
      query = table.concat(lines, "\n")
   else
      -- Fall back to visual selection
      query = input.get_visual_selection()
   end
   
   if not query or query == "" then
      vim.notify("No query selected", vim.log.levels.WARN)
      return
   end
   
   M.validate_query(query)
end

return M