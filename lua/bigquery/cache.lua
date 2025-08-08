-- BigQuery intelligent caching system
local M = {}

local cache_dir = vim.fn.stdpath('cache') .. '/bigquery'

-- Cache configuration with different TTLs
M.config = {
  projects = { ttl = 86400 },    -- 24 hours
  datasets = { ttl = 14400 },    -- 4 hours
  tables = { ttl = 3600 },       -- 1 hour
  schemas = { ttl = 43200 },     -- 12 hours
  temp_tables = { ttl = 300 }    -- 5 minutes for temp/scratch
}

-- In-memory cache
M.cache = {
  projects = { data = nil, last_update = 0 },
  datasets = {},  -- Per-project
  tables = {},    -- Per-dataset
  schemas = {}    -- Per-table
}

-- Initialize cache directory
function M.init()
  vim.fn.mkdir(cache_dir, 'p')
end

-- Check if dataset is temporary (shorter cache)
function M.is_temp_dataset(dataset_name)
  local temp_patterns = {
    'scratch', 'temp', 'tmp', 'staging', 'dev', 
    'sandbox', 'test', 'experiment'
  }
  
  dataset_name = dataset_name:lower()
  for _, pattern in ipairs(temp_patterns) do
    if dataset_name:match(pattern) then
      return true
    end
  end
  return false
end

-- Get cache key for different types
function M.get_cache_key(type, ...)
  local parts = {...}
  if type == 'projects' then
    return 'projects'
  elseif type == 'datasets' then
    return 'datasets:' .. parts[1]  -- project
  elseif type == 'tables' then
    return 'tables:' .. parts[1] .. '.' .. parts[2]  -- project.dataset
  elseif type == 'schema' then
    return 'schema:' .. table.concat(parts, '.')  -- full table ref
  end
end

-- Get with cache
function M.get(cache_type, key, fetch_fn)
  local cache_key = M.get_cache_key(cache_type, key)
  local cache_entry = M.cache[cache_type]
  
  -- Handle nested cache structure
  if cache_type ~= 'projects' then
    cache_entry = cache_entry[cache_key] or { data = nil, last_update = 0 }
  end
  
  local now = os.time()
  local ttl = M.config[cache_type].ttl
  
  -- Check for temp datasets (shorter TTL)
  if cache_type == 'tables' and M.is_temp_dataset(key) then
    ttl = M.config.temp_tables.ttl
  end
  
  -- Return cached data if still valid
  if cache_entry.data and (now - cache_entry.last_update) < ttl then
    return cache_entry.data
  end
  
  -- Fetch new data
  local data = fetch_fn()
  
  -- Update cache
  cache_entry.data = data
  cache_entry.last_update = now
  
  if cache_type ~= 'projects' then
    M.cache[cache_type][cache_key] = cache_entry
  else
    M.cache.projects = cache_entry
  end
  
  return data
end

-- Invalidate cache
function M.invalidate(cache_type, key)
  if cache_type == 'projects' then
    M.cache.projects = { data = nil, last_update = 0 }
  elseif key then
    local cache_key = M.get_cache_key(cache_type, key)
    if M.cache[cache_type] and M.cache[cache_type][cache_key] then
      M.cache[cache_type][cache_key] = { data = nil, last_update = 0 }
    end
  else
    -- Clear entire cache type
    M.cache[cache_type] = {}
  end
end

-- Clear all caches
function M.clear_all()
  M.cache = {
    projects = { data = nil, last_update = 0 },
    datasets = {},
    tables = {},
    schemas = {}
  }
end

-- Save cache to disk (for persistence across sessions)
function M.save_to_disk(key, data)
  local file = cache_dir .. '/' .. key:gsub('[:./ ]', '_') .. '.json'
  local ok, json = pcall(vim.json.encode, data)
  if ok then
    vim.fn.writefile({json}, file)
  end
end

-- Load cache from disk
function M.load_from_disk(key)
  local file = cache_dir .. '/' .. key:gsub('[:./ ]', '_') .. '.json'
  if vim.fn.filereadable(file) == 1 then
    local content = vim.fn.readfile(file)
    if #content > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(content))
      if ok then
        return data
      end
    end
  end
  return nil
end

-- Get cache stats
function M.get_stats()
  local stats = {
    projects = M.cache.projects.data and 1 or 0,
    datasets = vim.tbl_count(M.cache.datasets),
    tables = vim.tbl_count(M.cache.tables),
    schemas = vim.tbl_count(M.cache.schemas)
  }
  return stats
end

M.init()

return M