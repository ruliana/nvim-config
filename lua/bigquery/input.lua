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
  
  -- Get the visual mode type from the last visual selection
  local vmode = vim.fn.visualmode()
  
  -- Handle single line selection
  if #lines == 1 then
    local line = lines[1]
    -- Handle character-wise visual selection (v mode)
    if vmode == "v" or vmode == "s" then
      -- For character-wise selection, extract only the selected part
      lines[1] = string.sub(line, start_col, end_col)
    end
    -- For line-wise (V) or block-wise (^V), use the full line
  else
    -- Handle multi-line selection
    if vmode == "v" or vmode == "s" then
      -- Character-wise: trim first and last lines
      lines[1] = string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
    -- For line-wise (V), use full lines as-is
  end
  
  -- Check if all non-empty lines start with '--'
  local all_commented = true
  for _, line in ipairs(lines) do
    -- Skip empty lines and lines with only whitespace
    if not line:match("^%s*$") then
      -- Check if line starts with '--' (possibly with leading whitespace)
      if not line:match("^%s*%-%-") then
        all_commented = false
        break
      end
    end
  end
  
  -- If all non-empty lines are commented, remove the comment prefix
  if all_commented then
    for i, line in ipairs(lines) do
      -- Only process non-empty lines
      if not line:match("^%s*$") then
        -- Remove '--' and optional space after it, preserving indentation
        lines[i] = line:gsub("^(%s*)%-%-%s?", "%1")
      end
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
-- Get the query at the cursor position (delimited by semicolons at the start of lines)
function M.get_query_at_cursor()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Find the query boundaries (lines starting with semicolon or buffer boundaries)
  local query_start = cursor_line
  local query_end = cursor_line
  
  -- Track if we're inside a CTE or parentheses
  local open_parens = 0
  local in_cte = false
  
  -- Search backwards for the start of the query
  for i = cursor_line, 1, -1 do
    local line = lines[i]
    
    -- Check for CTE keywords (case insensitive)
    if line:lower():match("^%s*with%s+") or line:lower():match("^with%s+") then
      in_cte = true
      query_start = i
      -- Don't break yet - check if there's a CREATE TABLE before this
      -- Continue searching backwards for CREATE TABLE ... AS
      for j = i - 1, math.max(1, i - 20), -1 do
        local prev_line = lines[j]
        local lower_line = prev_line:lower()
        -- Check for CREATE TABLE/VIEW/OR REPLACE patterns
        if (lower_line:match("create%s+table") or 
            lower_line:match("create%s+or%s+replace%s+table") or
            lower_line:match("create%s+view") or
            lower_line:match("create%s+or%s+replace%s+view") or
            lower_line:match("create%s+temp%s+table") or
            lower_line:match("create%s+temporary%s+table")) and 
           lower_line:match("%s+as%s*$") then
          -- Found CREATE ... AS before WITH
          -- Include any comments before the CREATE statement
          local create_start = j
          for k = j - 1, math.max(1, j - 10), -1 do
            if lines[k]:match("^%s*%-%-") or lines[k]:match("^%s*$") then
              create_start = k
            else
              break
            end
          end
          query_start = create_start
          break
        elseif prev_line:match("^;") then
          -- Stop if we hit a query delimiter
          break
        end
      end
      break
    end
    
    -- Count parentheses (simple approach, doesn't handle strings)
    for char in line:gmatch(".") do
      if char == "(" then
        open_parens = open_parens - 1
      elseif char == ")" then
        open_parens = open_parens + 1
      end
    end
    
    -- Check for query delimiter (semicolon at start of line)
    if i < cursor_line and lines[i]:match("^;") then
      -- If we have unmatched parens or in CTE, keep going
      if open_parens == 0 and not in_cte then
        query_start = i + 1  -- Start after the semicolon line
        break
      end
    end
    
    query_start = i
  end
  
  -- Reset counters for forward search
  open_parens = 0
  in_cte = false
  
  -- Check if we started with a CTE
  if lines[query_start] and lines[query_start]:lower():match("^%s*with%s+") then
    in_cte = true
  end
  
  -- Search forwards for the end of the query
  for i = query_start, #lines do
    local line = lines[i]
    
    -- First check if this line (after cursor) starts with semicolon delimiter
    if i > cursor_line and line:match("^;") then
      if open_parens == 0 then
        query_end = i - 1
        break
      end
    end
    
    -- Count parentheses
    for char in line:gmatch(".") do
      if char == "(" then
        open_parens = open_parens + 1
      elseif char == ")" then
        open_parens = open_parens - 1
      end
    end
    
    -- Check for end of statement (semicolon at end of line or standalone)
    if line:match(";%s*$") and open_parens == 0 then
      query_end = i
      break
    end
    
    query_end = i
  end
  
  -- Extract the query lines
  local query_lines = {}
  for i = query_start, query_end do
    -- Skip the line if it only contains a semicolon
    if not lines[i]:match("^;%s*$") then
      table.insert(query_lines, lines[i])
    end
  end
  
  -- Trim empty lines from the beginning and end
  while #query_lines > 0 and query_lines[1]:match("^%s*$") do
    table.remove(query_lines, 1)
  end
  
  while #query_lines > 0 and query_lines[#query_lines]:match("^%s*$") do
    table.remove(query_lines)
  end
  
  if #query_lines == 0 then
    return nil
  end
  
  return table.concat(query_lines, "\n")
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