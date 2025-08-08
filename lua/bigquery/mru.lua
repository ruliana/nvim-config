-- BigQuery MRU (Most Recently Used) table tracking
local M = {}

local mru_file = vim.fn.stdpath('data') .. '/bigquery_mru.json'
local MAX_MRU = 50

-- Load MRU list from disk
function M.load()
  if vim.fn.filereadable(mru_file) == 1 then
    local content = vim.fn.readfile(mru_file)
    if #content > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(content))
      if ok then
        return data
      end
    end
  end
  return {}
end

-- Save MRU list to disk
function M.save(mru_data)
  local ok, json = pcall(vim.json.encode, mru_data)
  if ok then
    vim.fn.mkdir(vim.fn.fnamemodify(mru_file, ':h'), 'p')
    vim.fn.writefile({json}, mru_file)
  end
end

-- Add a table to MRU
function M.add(table_ref)
  local mru = M.load()
  local now = os.time()
  
  -- Find existing entry
  local existing_idx = nil
  for i, entry in ipairs(mru) do
    if entry.ref == table_ref then
      existing_idx = i
      break
    end
  end
  
  -- Update or create entry
  local entry = {
    ref = table_ref,
    last_used = now,
    use_count = 1
  }
  
  if existing_idx then
    entry.use_count = mru[existing_idx].use_count + 1
    table.remove(mru, existing_idx)
  end
  
  -- Add to front
  table.insert(mru, 1, entry)
  
  -- Trim to max size
  while #mru > MAX_MRU do
    table.remove(mru)
  end
  
  M.save(mru)
  return entry
end

-- Get MRU tables sorted by recency
function M.get_tables(limit)
  local mru = M.load()
  limit = limit or MAX_MRU
  
  local result = {}
  for i = 1, math.min(limit, #mru) do
    table.insert(result, mru[i])
  end
  
  return result
end

-- Clear MRU cache
function M.clear()
  M.save({})
end

-- Get a specific table's MRU info
function M.get_info(table_ref)
  local mru = M.load()
  for _, entry in ipairs(mru) do
    if entry.ref == table_ref then
      return entry
    end
  end
  return nil
end

return M