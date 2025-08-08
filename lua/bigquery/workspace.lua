-- BigQuery workspace configuration
local M = {}

-- Default configuration
M.default_config = {
  pinned_tables = {},
  frequently_used_datasets = {},
  ignore_patterns = {
    "*.temp_*",
    "*.tmp_*",
    "*_backup_*",
    "*_old",
    "*_test"
  },
  default_project = nil,
  default_location = "US"
}

-- Current workspace config
M.config = nil

-- Find and load workspace configuration
function M.load()
  -- Look for .bqrc.json in current directory and parents
  local config_files = {
    '.bqrc.json',
    '.bqrc',
    '.bigqueryrc',
    '.bigquery.json'
  }
  
  for _, filename in ipairs(config_files) do
    local config_file = vim.fn.findfile(filename, '.;')
    if config_file ~= '' then
      local content = vim.fn.readfile(config_file)
      if #content > 0 then
        local ok, config = pcall(vim.json.decode, table.concat(content))
        if ok then
          M.config = vim.tbl_deep_extend('force', M.default_config, config)
          return M.config
        end
      end
    end
  end
  
  -- No config found, use defaults
  M.config = vim.deepcopy(M.default_config)
  return M.config
end

-- Get pinned tables
function M.get_pinned_tables()
  if not M.config then
    M.load()
  end
  return M.config.pinned_tables or {}
end

-- Get frequently used datasets
function M.get_frequent_datasets()
  if not M.config then
    M.load()
  end
  return M.config.frequently_used_datasets or {}
end

-- Check if a table matches ignore patterns
function M.should_ignore(table_name)
  if not M.config then
    M.load()
  end
  
  for _, pattern in ipairs(M.config.ignore_patterns) do
    -- Convert glob pattern to Lua pattern
    local lua_pattern = pattern:gsub('%.', '%%.'):gsub('*', '.*')
    if table_name:match(lua_pattern) then
      return true
    end
  end
  
  return false
end

-- Get default project
function M.get_default_project()
  if not M.config then
    M.load()
  end
  return M.config.default_project
end

-- Add a table to pinned list
function M.pin_table(table_ref)
  if not M.config then
    M.load()
  end
  
  -- Check if already pinned
  for _, pinned in ipairs(M.config.pinned_tables) do
    if pinned == table_ref then
      return false  -- Already pinned
    end
  end
  
  table.insert(M.config.pinned_tables, table_ref)
  M.save()
  return true
end

-- Remove a table from pinned list
function M.unpin_table(table_ref)
  if not M.config then
    M.load()
  end
  
  for i, pinned in ipairs(M.config.pinned_tables) do
    if pinned == table_ref then
      table.remove(M.config.pinned_tables, i)
      M.save()
      return true
    end
  end
  
  return false
end

-- Save current config to workspace file
function M.save()
  if not M.config then
    return false
  end
  
  local config_file = vim.fn.getcwd() .. '/.bqrc.json'
  local ok, json = pcall(vim.json.encode, M.config)
  if ok then
    vim.fn.writefile({json}, config_file)
    return true
  end
  
  return false
end

-- Create a sample config file
function M.create_sample_config()
  local sample = {
    pinned_tables = {
      "your-project.dataset.frequently_used_table",
      "analytics.core.users"
    },
    frequently_used_datasets = {
      "your-project.your_dataset",
      "analytics.core"
    },
    ignore_patterns = {
      "*.temp_*",
      "*.tmp_*",
      "*_backup_*"
    },
    default_project = "your-default-project",
    default_location = "US"
  }
  
  local config_file = vim.fn.getcwd() .. '/.bqrc.json'
  local ok, json = pcall(vim.json.encode, sample)
  if ok then
    vim.fn.writefile(vim.split(json, '\n'), config_file)
    print("Created sample .bqrc.json config file")
    return true
  end
  
  return false
end

-- Reload configuration
function M.reload()
  M.config = nil
  return M.load()
end

return M