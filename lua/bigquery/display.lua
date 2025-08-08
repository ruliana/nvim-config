local M = {}

local function create_buffer(name, filetype)
  -- First, try to find and reuse existing BigQuery Results buffer
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match("BigQuery Results") then
        -- Reuse this buffer - clear its contents and return it
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
        vim.bo[buf].filetype = filetype or "bigquery"
        return buf
      end
    end
  end
  
  -- No existing buffer found, create a new one
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Use a timestamp to make the name unique if needed
  local unique_name = name .. " [" .. os.date("%H:%M:%S") .. "]"
  vim.api.nvim_buf_set_name(buf, unique_name)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype or "bigquery"
  
  return buf
end

local function open_split(buf, config)
  -- Check if buffer is already visible in a window
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      -- Buffer is already visible, just switch to it
      vim.api.nvim_set_current_win(win)
      return win
    end
  end
  
  -- Buffer not visible, create a new split
  local split_cmd = "split"
  
  if config.split_direction == "below" then
    split_cmd = "belowright " .. config.split_size .. "split"
  elseif config.split_direction == "above" then
    split_cmd = "aboveleft " .. config.split_size .. "split"
  elseif config.split_direction == "left" then
    split_cmd = "leftabove " .. config.split_size .. "vsplit"
  elseif config.split_direction == "right" then
    split_cmd = "rightbelow " .. config.split_size .. "vsplit"
  end
  
  vim.cmd(split_cmd)
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  
  -- Set window options
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  
  return win
end

local function format_json_lines(lines, config)
  if not config.auto_format then
    return lines
  end
  
  -- Try to parse and pretty-print JSON
  local json_str = table.concat(lines, "\n")
  local ok, decoded = pcall(vim.json.decode, json_str)
  
  if ok then
    local formatted = vim.json.encode(decoded)
    return vim.split(formatted, "\n")
  end
  
  return lines
end

function M.show_results(lines, config, query, elapsed)
  local filetype = "text"
  if config.format == "json" then
    filetype = "json"
    lines = format_json_lines(lines, config)
  elseif config.format == "csv" then
    filetype = "csv"
  end
  
  local buf = create_buffer("BigQuery Results", filetype)
  
  -- Add header with query info
  local header = {}
  table.insert(header, "-- BigQuery Results")
  if config.show_query_time then
    table.insert(header, string.format("-- Query executed in %.2f seconds", elapsed))
  end
  table.insert(header, "-- Format: " .. config.format)
  table.insert(header, "-- Rows: " .. #lines)
  table.insert(header, string.rep("-", 60))
  table.insert(header, "")
  
  -- Combine header and results
  local all_lines = {}
  vim.list_extend(all_lines, header)
  vim.list_extend(all_lines, lines)
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
  vim.bo[buf].modifiable = false
  
  -- Open the buffer in a split
  open_split(buf, config)
  
  -- Add keymaps for the results buffer
  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "q", "<cmd>close<cr>", opts)
  vim.keymap.set("n", "<esc>", "<cmd>close<cr>", opts)
  vim.keymap.set("n", "gq", function()
    -- Show the original query in a floating window
    local float_opts = {
      relative = "editor",
      width = math.min(80, vim.o.columns - 4),
      height = math.min(20, vim.o.lines - 4),
      col = (vim.o.columns - 80) / 2,
      row = (vim.o.lines - 20) / 2,
      style = "minimal",
      border = "rounded",
    }
    
    local float_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, vim.split(query, "\n"))
    vim.bo[float_buf].filetype = "sql"
    vim.bo[float_buf].modifiable = false
    
    local float_win = vim.api.nvim_open_win(float_buf, true, float_opts)
    vim.keymap.set("n", "q", function()
      vim.api.nvim_win_close(float_win, true)
    end, { buffer = float_buf })
    vim.keymap.set("n", "<esc>", function()
      vim.api.nvim_win_close(float_win, true)
    end, { buffer = float_buf })
  end, opts)
  
  vim.notify("Query completed successfully", vim.log.levels.INFO)
end

function M.show_error(error_lines, query)
  local buf = create_buffer("BigQuery Error", "text")
  
  -- Format error message
  local lines = {
    "BigQuery Execution Error",
    string.rep("=", 60),
    "",
    "Query:",
    string.rep("-", 60),
  }
  
  -- Add query lines
  for _, line in ipairs(vim.split(query, "\n")) do
    table.insert(lines, line)
  end
  
  table.insert(lines, "")
  table.insert(lines, "Error:")
  table.insert(lines, string.rep("-", 60))
  
  -- Add error lines
  vim.list_extend(lines, error_lines)
  
  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  
  -- Open the buffer in a split
  open_split(buf, { split_direction = "below", split_size = 15 })
  
  -- Add keymaps for the error buffer
  local opts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "q", "<cmd>close<cr>", opts)
  vim.keymap.set("n", "<esc>", "<cmd>close<cr>", opts)
end

return M