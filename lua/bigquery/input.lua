local M = {}

function M.get_buffer_query()
  -- Check if current buffer is a BigQuery results buffer
  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name:match("BigQuery Results") or buf_name:match("BigQuery Error") then
    -- Don't read from results/error buffers
    -- Try to find a SQL buffer
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local name = vim.api.nvim_buf_get_name(buf)
        local ft = vim.api.nvim_buf_get_option(buf, "filetype")
        if (ft == "sql" or ft == "bq" or name:match("%.sql$") or name:match("%.bq$")) 
           and not name:match("BigQuery") then
          -- Found a SQL buffer, read from it
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          
          -- Filter out empty lines at the beginning and end
          local start_idx = 1
          local end_idx = #lines
          
          while start_idx <= #lines and lines[start_idx]:match("^%s*$") do
            start_idx = start_idx + 1
          end
          
          while end_idx >= 1 and lines[end_idx]:match("^%s*$") do
            end_idx = end_idx - 1
          end
          
          if start_idx > end_idx then
            return nil
          end
          
          -- Extract the relevant lines
          local query_lines = {}
          for i = start_idx, end_idx do
            table.insert(query_lines, lines[i])
          end
          
          return table.concat(query_lines, "\n")
        end
      end
    end
    
    vim.notify("No SQL buffer found. Please open a .sql file first.", vim.log.levels.WARN)
    return nil
  end
  
  -- Current buffer is not a results buffer, read from it
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Filter out empty lines at the beginning and end
  local start_idx = 1
  local end_idx = #lines
  
  while start_idx <= #lines and lines[start_idx]:match("^%s*$") do
    start_idx = start_idx + 1
  end
  
  while end_idx >= 1 and lines[end_idx]:match("^%s*$") do
    end_idx = end_idx - 1
  end
  
  if start_idx > end_idx then
    return nil
  end
  
  -- Extract the relevant lines
  local query_lines = {}
  for i = start_idx, end_idx do
    table.insert(query_lines, lines[i])
  end
  
  return table.concat(query_lines, "\n")
end

function M.get_visual_selection()
  -- Get the visual selection range
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local start_col = start_pos[3]
  local end_col = end_pos[3]
  
  -- Get the lines
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  
  if #lines == 0 then
    return nil
  end
  
  -- Handle single line selection
  if #lines == 1 then
    local line = lines[1]
    -- Handle character-wise visual selection
    if vim.fn.mode() == "v" then
      lines[1] = string.sub(line, start_col, end_col)
    end
  else
    -- Handle multi-line selection
    if vim.fn.mode() == "v" then
      -- Character-wise: trim first and last lines
      lines[1] = string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end
  
  return table.concat(lines, "\n")
end

function M.prompt_for_query()
  -- Create a simple input prompt
  local query = vim.fn.input({
    prompt = "BigQuery> ",
    default = "",
    cancelreturn = nil,
  })
  
  if query == "" then
    return nil
  end
  
  return query
end

function M.get_query_from_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    vim.notify("Could not open file: " .. filepath, vim.log.levels.ERROR)
    return nil
  end
  
  local content = file:read("*all")
  file:close()
  
  return content
end

-- Get table reference under cursor
function M.get_table_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  
  -- Try to find a table reference that includes the cursor position
  -- Match 3-part references with backticks
  for match_start, match, match_end in line:gmatch('()(`[^`]+%.[^`]+%.[^`]+`)()')  do
    if col >= match_start - 1 and col < match_end - 1 then
      return match:gsub('`', '')
    end
  end
  
  -- Match 2-part references with backticks
  for match_start, match, match_end in line:gmatch('()(`[^`]+%.[^`]+`)()')  do
    if col >= match_start - 1 and col < match_end - 1 then
      return match:gsub('`', '')
    end
  end
  
  -- Try without backticks - 3-part
  for match_start, match, match_end in line:gmatch('()([%w_%-]+%.[%w_%-]+%.[%w_%-]+)()')  do
    if col >= match_start - 1 and col < match_end - 1 then
      return match
    end
  end
  
  -- Try without backticks - 2-part
  for match_start, match, match_end in line:gmatch('()([%w_%-]+%.[%w_%-]+)()')  do
    if col >= match_start - 1 and col < match_end - 1 then
      return match
    end
  end
  
  return nil
end

return M