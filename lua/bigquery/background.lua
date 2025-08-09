-- Background refresh and pre-caching based on usage patterns
local M = {}

local api = require('bigquery.api')
local cache = require('bigquery.cache')
local tracker = require('bigquery.search_tracker')
local usage = require('bigquery.usage')

-- Background job handle
M.refresh_job = nil
M.is_running = false

-- Start background refresh
function M.start()
  if M.is_running then
    return
  end
  
  M.is_running = true
  
  -- Initial delay to let Neovim start
  vim.defer_fn(function()
    M.refresh_frequently_used()
  end, 5000)
  
  -- Schedule periodic refresh every 30 minutes
  M.refresh_job = vim.fn.timer_start(1800000, function()
    M.refresh_frequently_used()
  end, { ['repeat'] = -1 })
end

-- Stop background refresh
function M.stop()
  if M.refresh_job then
    vim.fn.timer_stop(M.refresh_job)
    M.refresh_job = nil
  end
  M.is_running = false
end

-- Refresh frequently used tables and their schemas
function M.refresh_frequently_used()
  vim.schedule(function()
    -- Get tables to refresh from multiple sources
    local tables_to_refresh = {}
    local seen = {}
    
    -- 1. Get from actual BigQuery usage
    local user_tables = usage.get_user_table_usage(7)
    for i = 1, math.min(20, #user_tables) do
      local table_ref = user_tables[i].table_ref
      if not seen[table_ref] then
        seen[table_ref] = true
        table.insert(tables_to_refresh, {
          ref = table_ref,
          priority = 1  -- Highest priority
        })
      end
    end
    
    -- 2. Get from search tracker
    local search_tables = tracker.get_tables_to_cache()
    for i = 1, math.min(10, #search_tables) do
      local table_ref = search_tables[i].table_ref
      if not seen[table_ref] then
        seen[table_ref] = true
        table.insert(tables_to_refresh, {
          ref = table_ref,
          priority = 2
        })
      end
    end
    
    -- 3. Get from MRU
    local mru = require('bigquery.mru')
    local mru_tables = mru.get_tables(10)
    for _, entry in ipairs(mru_tables) do
      if not seen[entry.ref] then
        seen[entry.ref] = true
        table.insert(tables_to_refresh, {
          ref = entry.ref,
          priority = 3
        })
      end
    end
    
    -- Refresh schemas for top tables asynchronously
    for i = 1, math.min(5, #tables_to_refresh) do
      local table_ref = tables_to_refresh[i].ref
      vim.defer_fn(function()
        api.get_schema_async(table_ref, function(schema)
          -- Schema is now cached, no need to notify
        end)
      end, i * 1000)  -- Stagger requests
    end
  end)
end

-- Pre-warm cache with common searches
function M.prewarm_cache()
  -- Get frequent search terms
  local frequent_terms = tracker.get_frequent_terms(5)
  
  for _, term_data in ipairs(frequent_terms) do
    if #term_data.term >= 4 then
      vim.defer_fn(function()
        -- Trigger search to populate cache
        api.global_search(term_data.term, 20)
      end, 2000)
    end
  end
end

-- Get cache statistics
function M.get_stats()
  local stats = cache.get_stats()
  local tracker_terms = tracker.get_frequent_terms(100)
  
  return {
    cache = stats,
    frequent_searches = #tracker_terms,
    background_running = M.is_running
  }
end

return M