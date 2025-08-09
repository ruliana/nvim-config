-- Track actual BigQuery table usage from INFORMATION_SCHEMA
local M = {}

local cache = require('bigquery.cache')
local api = require('bigquery.api')

-- Get user's email for filtering
function M.get_user_email()
  -- Try to get from gcloud config
  local email = vim.fn.system('gcloud config get-value account 2>/dev/null'):gsub('%s+', '')
  if email and email ~= '' then
    return email
  end
  
  -- Fallback to git config
  email = vim.fn.system('git config user.email 2>/dev/null'):gsub('%s+', '')
  if email and email ~= '' then
    return email
  end
  
  return nil
end

-- Get tables used by current user from BigQuery audit logs
function M.get_user_table_usage(days_back)
  days_back = days_back or 7
  local user_email = M.get_user_email()
  
  -- If no user email, just return empty list without caching
  if not user_email then
    return {}
  end
  
  -- Cache key includes user and days to allow different time ranges
  local cache_key = user_email .. ':' .. days_back
  
  return cache.get('user_usage', cache_key, function()
    local query = string.format([[
      WITH job_tables AS (
        SELECT 
          DISTINCT table_ref.project_id,
          table_ref.dataset_id,
          table_ref.table_id,
          COUNT(*) OVER (PARTITION BY table_ref.project_id, table_ref.dataset_id, table_ref.table_id) as use_count,
          MAX(creation_time) OVER (PARTITION BY table_ref.project_id, table_ref.dataset_id, table_ref.table_id) as last_used
        FROM `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`,
          UNNEST(referenced_tables) as table_ref
        WHERE DATE(creation_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL %d DAY)
          AND user_email = '%s'
          AND statement_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'MERGE')
      )
      SELECT 
        CONCAT(project_id, '.', dataset_id, '.', table_id) as table_ref,
        use_count,
        last_used
      FROM job_tables
      ORDER BY use_count DESC, last_used DESC
      LIMIT 100
    ]], days_back, user_email)
    
    -- Execute the query
    local result = api.execute_bq(
      string.format("query --use_legacy_sql=false '%s'", query:gsub("'", "\\'")),
      true
    )
    
    if not result then
      return {}
    end
    
    local usage_data = {}
    for _, row in ipairs(result) do
      table.insert(usage_data, {
        table_ref = row.table_ref,
        use_count = tonumber(row.use_count) or 0,
        last_used = row.last_used
      })
    end
    
    return usage_data
  end)
end

-- Get frequently joined tables (tables that appear together in queries)
function M.get_related_tables(table_ref)
  local user_email = M.get_user_email()
  if not user_email then
    return {}
  end
  
  -- Parse the table reference
  local project, dataset, table_name = table_ref:match('([^.]+)%.([^.]+)%.([^.]+)')
  if not project then
    return {}
  end
  
  local query = string.format([[
    WITH target_queries AS (
      SELECT 
        job_id,
        creation_time
      FROM `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`,
        UNNEST(referenced_tables) as table_ref
      WHERE DATE(creation_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
        AND user_email = '%s'
        AND table_ref.project_id = '%s'
        AND table_ref.dataset_id = '%s'
        AND table_ref.table_id = '%s'
    ),
    related_tables AS (
      SELECT 
        table_ref.project_id,
        table_ref.dataset_id,
        table_ref.table_id,
        COUNT(DISTINCT j.job_id) as co_occurrence_count
      FROM `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT` j
      JOIN target_queries tq ON j.job_id = tq.job_id,
        UNNEST(j.referenced_tables) as table_ref
      WHERE NOT (
        table_ref.project_id = '%s' 
        AND table_ref.dataset_id = '%s'
        AND table_ref.table_id = '%s'
      )
      GROUP BY 1, 2, 3
    )
    SELECT 
      CONCAT(project_id, '.', dataset_id, '.', table_id) as related_table,
      co_occurrence_count
    FROM related_tables
    ORDER BY co_occurrence_count DESC
    LIMIT 20
  ]], user_email, project, dataset, table_name, project, dataset, table_name)
  
  local result = api.execute_bq(
    string.format("query --use_legacy_sql=false '%s'", query:gsub("'", "\\'")),
    true
  )
  
  if not result then
    return {}
  end
  
  local related = {}
  for _, row in ipairs(result) do
    table.insert(related, {
      table_ref = row.related_table,
      count = tonumber(row.co_occurrence_count) or 0
    })
  end
  
  return related
end

-- Combine MRU with actual usage for better recommendations
function M.get_smart_recommendations()
  local recommendations = {}
  local seen = {}
  
  -- Get actual usage data
  local usage = M.get_user_table_usage(7)
  
  -- Add usage-based tables with high priority
  for _, entry in ipairs(usage) do
    if not seen[entry.table_ref] then
      seen[entry.table_ref] = true
      table.insert(recommendations, {
        table_ref = entry.table_ref,
        source = "usage",
        score = entry.use_count * 10,  -- Weight actual usage heavily
        last_used = entry.last_used
      })
    end
  end
  
  -- Add MRU tables
  local mru = require('bigquery.mru')
  local mru_tables = mru.get_tables(50)
  
  for _, entry in ipairs(mru_tables) do
    if not seen[entry.ref] then
      seen[entry.ref] = true
      table.insert(recommendations, {
        table_ref = entry.ref,
        source = "mru",
        score = entry.use_count,
        last_used = entry.last_used
      })
    else
      -- Boost score if in both
      for _, rec in ipairs(recommendations) do
        if rec.table_ref == entry.ref then
          rec.score = rec.score + entry.use_count
          rec.source = "both"
          break
        end
      end
    end
  end
  
  -- Sort by score
  table.sort(recommendations, function(a, b)
    return a.score > b.score
  end)
  
  return recommendations
end

return M