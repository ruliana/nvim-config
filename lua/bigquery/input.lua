local M = {}

function M.get_buffer_query()
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

return M