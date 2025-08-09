-- Track search terms and their frequency for intelligent caching
local M = {}

local data_dir = vim.fn.stdpath('data') .. '/bigquery'
local tracker_file = data_dir .. '/search_tracker.json'

-- Initialize data directory
vim.fn.mkdir(data_dir, 'p')

-- In-memory tracker
M.search_terms = {}

-- Load tracker from disk
function M.load()
  if vim.fn.filereadable(tracker_file) == 1 then
    local content = vim.fn.readfile(tracker_file)
    if #content > 0 then
      local ok, data = pcall(vim.json.decode, table.concat(content))
      if ok then
        M.search_terms = data
      end
    end
  end
end

-- Save tracker to disk
function M.save()
  local ok, json = pcall(vim.json.encode, M.search_terms)
  if ok then
    vim.fn.writefile({json}, tracker_file)
  end
end

-- Track a search term
function M.track(term)
  if not term or #term < 3 then
    return
  end
  
  -- Normalize the term
  term = term:lower():gsub('^[^a-z0-9_]+', ''):gsub('[^a-z0-9_]+$', '')
  
  if not M.search_terms[term] then
    M.search_terms[term] = {
      count = 0,
      last_used = 0,
      tables_found = {},
      first_seen = os.time()
    }
  end
  
  M.search_terms[term].count = M.search_terms[term].count + 1
  M.search_terms[term].last_used = os.time()
  
  -- Save periodically (every 10 searches)
  local total_searches = 0
  for _, v in pairs(M.search_terms) do
    total_searches = total_searches + v.count
  end
  
  if total_searches % 10 == 0 then
    M.save()
  end
end

-- Track found tables for a search term
function M.track_results(term, tables)
  if not term or not M.search_terms[term] then
    return
  end
  
  -- Store up to 10 most recent tables found
  M.search_terms[term].tables_found = {}
  for i = 1, math.min(10, #tables) do
    table.insert(M.search_terms[term].tables_found, tables[i])
  end
end

-- Get frequently searched terms
function M.get_frequent_terms(limit)
  limit = limit or 20
  local terms = {}
  
  for term, data in pairs(M.search_terms) do
    table.insert(terms, {
      term = term,
      count = data.count,
      last_used = data.last_used,
      tables = data.tables_found
    })
  end
  
  -- Sort by frequency and recency
  table.sort(terms, function(a, b)
    -- Weight: 70% frequency, 30% recency
    local now = os.time()
    local a_recency = math.max(0, 1 - (now - a.last_used) / 86400) -- Decay over 24h
    local b_recency = math.max(0, 1 - (now - b.last_used) / 86400)
    
    local a_score = (a.count * 0.7) + (a_recency * 100 * 0.3)
    local b_score = (b.count * 0.7) + (b_recency * 100 * 0.3)
    
    return a_score > b_score
  end)
  
  -- Return top N
  local result = {}
  for i = 1, math.min(limit, #terms) do
    result[i] = terms[i]
  end
  
  return result
end

-- Get tables that should be pre-cached based on search patterns
function M.get_tables_to_cache()
  local tables = {}
  local seen = {}
  
  -- Get frequently searched terms
  local frequent = M.get_frequent_terms(10)
  
  for _, term_data in ipairs(frequent) do
    for _, table_ref in ipairs(term_data.tables or {}) do
      if not seen[table_ref] then
        seen[table_ref] = true
        table.insert(tables, {
          table_ref = table_ref,
          score = term_data.count
        })
      end
    end
  end
  
  return tables
end

-- Initialize
M.load()

return M