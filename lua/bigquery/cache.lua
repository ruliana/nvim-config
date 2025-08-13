-- BigQuery intelligent caching system
local M = {}

local cache_dir = vim.fn.stdpath('cache') .. '/bigquery'

-- Cache configuration with different TTLs
M.config = {
  projects = { ttl = 86400 },    -- 24 hours
  datasets = { ttl = 14400 },    -- 4 hours
  tables = { ttl = 3600 },       -- 1 hour
  schemas = { ttl = 43200 },     -- 12 hours
  temp_tables = { ttl = 300 },   -- 5 minutes for temp/scratch
  user_usage = { ttl = 3600 },   -- 1 hour for usage data
  validation = { ttl = 7200, max_entries = 500 }  -- 2 hours, 500 entries default
}

-- In-memory cache
M.cache = {
  projects = { data = nil, last_update = 0 },
  datasets = {},  -- Per-project
  tables = {},    -- Per-dataset
  schemas = {},   -- Per-table
  user_usage = {}, -- Per-user usage patterns
  validation = {} -- Query validation results
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
  elseif type == 'user_usage' then
    return 'user_usage:' .. parts[1]  -- user_email:days_back
  else
    -- For any other type, just use the first part as-is
    return parts[1] or type
  end
end

-- Get with cache
function M.get(cache_type, key, fetch_fn)
  -- Validate inputs
  if not cache_type or not key then
    return fetch_fn and fetch_fn() or nil
  end
  
  -- Ensure cache type exists
  if not M.cache[cache_type] then
    if cache_type == 'projects' then
      M.cache[cache_type] = { data = nil, last_update = 0 }
    else
      M.cache[cache_type] = {}
    end
  end
  
  -- Handle different key formats
  local cache_key
  if cache_type == 'tables' and type(key) == 'string' and key:match('%.') then
    -- Split project.dataset format
    local project, dataset = key:match('([^.]+)%.([^.]+)')
    cache_key = M.get_cache_key(cache_type, project, dataset)
  else
    cache_key = M.get_cache_key(cache_type, key)
  end
  
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
    -- Ensure the cache type exists
    if not M.cache[cache_type] then
      M.cache[cache_type] = {}
    end
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
    schemas = {},
    user_usage = {},
    validation = {}
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
    schemas = vim.tbl_count(M.cache.schemas),
    validation = vim.tbl_count(M.cache.validation)
  }
  return stats
end

-- Normalize query for caching (collapse all whitespace to single space)
function M.normalize_query(query)
  if not query then return "" end
  -- Replace all whitespace sequences with single space and trim
  return query:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
end

-- Generate hash for a normalized query
function M.hash_query(query)
  local normalized = M.normalize_query(query)
  return vim.fn.sha256(normalized)
end

-- Get validation cache with LRU eviction
function M.get_validation(query_hash, ttl_override)
  local cache_entry = M.cache.validation[query_hash]
  if not cache_entry then
    return nil
  end
  
  local now = os.time()
  local ttl = ttl_override or M.config.validation.ttl
  
  -- Check if expired
  if (now - cache_entry.timestamp) > ttl then
    M.cache.validation[query_hash] = nil
    return nil
  end
  
  -- Update access info for LRU
  cache_entry.last_access = now
  cache_entry.access_count = (cache_entry.access_count or 0) + 1
  
  return cache_entry.result
end

-- Set validation cache with LRU eviction
function M.set_validation(query_hash, result, max_entries_override)
  local now = os.time()
  local max_entries = max_entries_override or M.config.validation.max_entries
  
  -- Clean expired entries first
  M.clean_expired_validation()
  
  -- Check if we need to evict (LRU)
  local count = vim.tbl_count(M.cache.validation)
  if count >= max_entries and not M.cache.validation[query_hash] then
    -- Only evict if we're adding a new entry (not updating existing)
    -- Find least recently used entry
    local lru_hash = nil
    local oldest_access = now + 1  -- Start with future time
    
    for hash, entry in pairs(M.cache.validation) do
      if hash ~= query_hash then  -- Don't evict the one we're about to add
        local last_access = entry.last_access or entry.timestamp
        if last_access < oldest_access then
          oldest_access = last_access
          lru_hash = hash
        end
      end
    end
    
    -- Evict the LRU entry
    if lru_hash then
      M.cache.validation[lru_hash] = nil
    end
  end
  
  -- Store the new entry
  M.cache.validation[query_hash] = {
    result = result,
    timestamp = now,
    last_access = now,
    access_count = 0
  }
end

-- Clean expired validation entries
function M.clean_expired_validation()
  local now = os.time()
  local ttl = M.config.validation.ttl
  
  for hash, entry in pairs(M.cache.validation) do
    if (now - entry.timestamp) > ttl then
      M.cache.validation[hash] = nil
    end
  end
end

-- Update validation cache config from workspace settings
function M.update_validation_config(validation_config)
  if validation_config then
    if validation_config.ttl then
      M.config.validation.ttl = validation_config.ttl
    end
    if validation_config.max_entries then
      M.config.validation.max_entries = validation_config.max_entries
    end
  end
end

M.init()

return M