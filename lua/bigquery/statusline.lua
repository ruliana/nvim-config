local M = {}

-- Get BigQuery status for statusline
function M.get_status()
  if vim.g.bigquery_status then
    return " " .. vim.g.bigquery_status .. " "
  end
  return ""
end

-- Setup statusline integration
function M.setup()
  -- Create an autocommand group for BigQuery statusline
  local augroup = vim.api.nvim_create_augroup("BigQueryStatusline", { clear = true })
  
  -- Set up statusline to include BigQuery status
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter", "CmdlineLeave" }, {
    group = augroup,
    pattern = { "*.sql", "*.bq" },
    callback = function()
      -- Store original statusline if not already stored
      if not vim.b.original_statusline then
        vim.b.original_statusline = vim.o.statusline
      end
      
      -- Add BigQuery status to statusline
      local bq_component = "%{luaeval('require(\"bigquery.statusline\").get_status()')}"
      
      -- If statusline is empty or default, create a simple one
      if vim.o.statusline == "" then
        vim.o.statusline = "%<%f %h%m%r" .. bq_component .. "%=%-14.(%l,%c%V%) %P"
      else
        -- Append to existing statusline
        if not vim.o.statusline:match("bigquery%.statusline") then
          vim.o.statusline = vim.o.statusline:gsub("%%=", bq_component .. "%%=")
        end
      end
    end
  })
  
  -- Restore original statusline when leaving SQL files
  vim.api.nvim_create_autocmd({ "BufLeave", "BufWinLeave" }, {
    group = augroup,
    pattern = { "*.sql", "*.bq" },
    callback = function()
      if vim.b.original_statusline then
        vim.o.statusline = vim.b.original_statusline
      end
    end
  })
end

return M