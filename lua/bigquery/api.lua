-- BigQuery API wrapper using bq CLI
local M = {}
local cache = require('bigquery.cache')
local workspace = require('bigquery.workspace')

-- Execute bq command and return parsed JSON
function M.execute_bq(cmd, parse_json)
  parse_json = parse_json ~= false  -- Default to true
  
  local full_cmd = 'bq '
  if parse_json then
    -- Put format flag BEFORE the command
    full_cmd = full_cmd .. '--format=json '
  end
  full_cmd = full_cmd .. cmd
  
  -- Redirect stderr to /dev/null to avoid "Waiting on..." messages
  full_cmd = full_cmd .. ' 2>/dev/null'
  
  local result = vim.fn.system(full_cmd)
  
  if vim.v.shell_error ~= 0 then
    return nil, result
  end
  
  if parse_json and result ~= '' then
    local ok, data = pcall(vim.json.decode, result)
    if ok then
      return data
    end
  end
  
  return result
end

-- Execute bq command asynchronously
function M.execute_bq_async(cmd, callback)
  local full_cmd = 'bq --format=json ' .. cmd
  
  vim.fn.jobstart(full_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        local output = table.concat(data, '\n')
        if output ~= '' then
          local ok, parsed = pcall(vim.json.decode, output)
          if ok then
            callback(parsed, nil)
          else
            callback(output, nil)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 then
        callback(nil, table.concat(data, '\n'))
      end
    end,
    on_exit = function(_, code, _)
      if code ~= 0 then
        callback(nil, 'Command failed with code: ' .. code)
      end
    end
  })
end

-- Get list of projects
function M.get_projects()
  return cache.get('projects', 'projects', function()
    local data, err = M.execute_bq('ls --projects --max_results=1000')
    if err then
      return {}
    end
    
    local projects = {}
    for _, project in ipairs(data or {}) do
      table.insert(projects, project.id or project.projectId)
    end
    
    return projects
  end)
end

-- Get datasets for a project
function M.get_datasets(project)
  project = project or workspace.get_default_project()
  if not project then
    return {}
  end
  
  return cache.get('datasets', project, function()
    local data, err = M.execute_bq('ls --project_id=' .. project .. ' --max_results=1000')
    if err then
      return {}
    end
    
    local datasets = {}
    for _, dataset in ipairs(data or {}) do
      local dataset_id = dataset.id or dataset.datasetId
      if dataset_id then
        -- Remove project prefix if present
        dataset_id = dataset_id:gsub('^[^:]+:', '')
        if not workspace.should_ignore(project .. '.' .. dataset_id) then
          table.insert(datasets, dataset_id)
        end
      end
    end
    
    return datasets
  end)
end

-- Get tables for a dataset
function M.get_tables(project, dataset)
  project = project or workspace.get_default_project()
  if not project or not dataset then
    return {}
  end
  
  local cache_key = project .. '.' .. dataset
  
  return cache.get('tables', cache_key, function()
    local dataset_ref = project .. ':' .. dataset
    local data, err = M.execute_bq('ls --max_results=1000 ' .. dataset_ref)
    if err then
      return {}
    end
    
    local tables = {}
    for _, tbl in ipairs(data or {}) do
      local table_id = tbl.id or tbl.tableId
      if table_id then
        -- Extract just the table name
        table_id = table_id:match('([^:%.]+)$')
        if table_id and not workspace.should_ignore(table_id) then
          table.insert(tables, {
            name = table_id,
            type = tbl.type or 'TABLE',
            full_ref = project .. '.' .. dataset .. '.' .. table_id
          })
        end
      end
    end
    
    return tables
  end)
end

-- Get schema for a table
function M.get_schema(table_ref)
  -- Parse table reference
  local project, dataset, tbl = table_ref:match('([^.]+)%.([^.]+)%.([^.]+)')
  if not project or not dataset or not tbl then
    -- Try 2-part reference with default project
    dataset, tbl = table_ref:match('([^.]+)%.([^.]+)')
    project = workspace.get_default_project()
    if not dataset or not tbl or not project then
      return {}
    end
  end
  
  return cache.get('schemas', table_ref, function()
    local full_ref = project .. ':' .. dataset .. '.' .. tbl
    local data, err = M.execute_bq('show --schema ' .. full_ref)
    if err then
      return {}
    end
    
    local fields = {}
    for _, field in ipairs(data or {}) do
      table.insert(fields, {
        name = field.name,
        type = field.type,
        mode = field.mode,
        description = field.description
      })
    end
    
    return fields
  end)
end

-- Get schema asynchronously
function M.get_schema_async(table_ref, callback)
  -- Check cache first
  local cached = cache.get('schemas', table_ref, function()
    return nil  -- Don't fetch synchronously
  end)
  
  if cached then
    callback(cached)
    return
  end
  
  -- Parse table reference
  local project, dataset, tbl = table_ref:match('([^.]+)%.([^.]+)%.([^.]+)')
  if not project or not dataset or not tbl then
    dataset, tbl = table_ref:match('([^.]+)%.([^.]+)')
    project = workspace.get_default_project()
    if not dataset or not tbl or not project then
      callback({})
      return
    end
  end
  
  local full_ref = project .. ':' .. dataset .. '.' .. tbl
  M.execute_bq_async('show --schema ' .. full_ref, function(data, err)
    if err then
      callback({})
      return
    end
    
    local fields = {}
    for _, field in ipairs(data or {}) do
      table.insert(fields, {
        name = field.name,
        type = field.type,
        mode = field.mode,
        description = field.description
      })
    end
    
    -- Update cache
    cache.cache.schemas['schema:' .. table_ref] = {
      data = fields,
      last_update = os.time()
    }
    
    callback(fields)
  end)
end

-- Global search across multiple datasets
function M.global_search_datasets(search_term, limit)
  limit = limit or 50
  
  -- Need at least 4 characters for global search
  if #search_term < 4 then
    return {}
  end
  
  local results = {}
  local default_project = workspace.get_default_project()
  
  -- Get search targets from configuration
  local search_targets = workspace.get_search_targets()
  
  -- Add default project if different from configured targets
  if default_project then
    local found = false
    for _, target in ipairs(search_targets) do
      if target.project == default_project then
        found = true
        break
      end
    end
    
    if not found then
      table.insert(search_targets, 1, {
        project = default_project,
        datasets = workspace.get_default_search_datasets()
      })
    end
  end
  
  -- Search each project/dataset combination
  for _, target in ipairs(search_targets) do
    for _, dataset in ipairs(target.datasets) do
      -- Get tables from cache or fetch
      local tables = M.get_tables(target.project, dataset)
      
      for _, tbl in ipairs(tables) do
        if tbl.name:lower():find(search_term:lower(), 1, true) then
          table.insert(results, {
            project = target.project,
            dataset = dataset,
            table_name = tbl.name,
            full_ref = tbl.full_ref
          })
          
          if #results >= limit then
            break
          end
        end
      end
      
      if #results >= limit then
        break
      end
    end
    
    if #results >= limit then
      break
    end
  end
  
  -- Track the search
  local tracker = require('bigquery.search_tracker')
  tracker.track(search_term)
  
  -- Track results
  local table_refs = {}
  for _, result in ipairs(results) do
    table.insert(table_refs, result.full_ref)
  end
  tracker.track_results(search_term, table_refs)
  
  return results
end

-- Global search using INFORMATION_SCHEMA (slow but comprehensive)
function M.global_search(search_term, limit)
  limit = limit or 50
  
  -- Need at least 4 characters for global search
  if #search_term < 4 then
    return {}
  end
  
  -- Try to get user's common projects from usage data
  local usage = require('bigquery.usage')
  local user_tables = usage.get_user_table_usage(30)
  
  -- Extract unique projects from user's usage
  local user_projects = {}
  local seen_projects = {}
  for _, entry in ipairs(user_tables) do
    local project = entry.table_ref:match('^([^.]+)')
    if project and not seen_projects[project] then
      seen_projects[project] = true
      table.insert(user_projects, project)
    end
  end
  
  -- If no usage data, use default project and common projects
  if #user_projects == 0 then
    local default_project = workspace.get_default_project()
    if default_project then
      table.insert(user_projects, default_project)
    end
    -- Add common data projects
    table.insert(user_projects, 'sdp-prd-cti-data')
    table.insert(user_projects, 'sdp-stg-cti-data')
    table.insert(user_projects, 'shopify-dw')
  end
  
  local all_results = {}
  
  -- Query each project's INFORMATION_SCHEMA
  for _, project in ipairs(user_projects) do
    local query = string.format([[
      SELECT 
        table_catalog as project,
        table_schema as dataset,
        table_name,
        CONCAT(table_catalog, '.', table_schema, '.', table_name) as full_ref
      FROM `%s.region-us.INFORMATION_SCHEMA.TABLES`
      WHERE LOWER(table_name) LIKE LOWER('%%%s%%')
        AND table_schema NOT IN ('INFORMATION_SCHEMA')
      ORDER BY table_name
      LIMIT %d
    ]], project, search_term:gsub("'", "''"), math.ceil(limit / #user_projects))
    
    local data = M.execute_bq(
      string.format("query --use_legacy_sql=false '%s'", query:gsub("'", "\\'")),
      true
    )
    
    if data and #data > 0 then
      for _, row in ipairs(data) do
        table.insert(all_results, row)
        if #all_results >= limit then
          break
        end
      end
    end
    
    if #all_results >= limit then
      break
    end
  end
  
  -- Track the search
  local tracker = require('bigquery.search_tracker')
  tracker.track(search_term)
  
  -- Track results
  local table_refs = {}
  for _, result in ipairs(all_results) do
    table.insert(table_refs, result.full_ref)
  end
  tracker.track_results(search_term, table_refs)
  
  return all_results
end

-- Search for tables (fallback to listing datasets and searching)
function M.search_tables(search_term, limit)
  limit = limit or 50
  
  -- Check if search term looks like a full or partial table reference
  local explicit_project, explicit_dataset, explicit_table = search_term:match('([^.]+)%.([^.]+)%.([^.]+)')
  
  if explicit_project and explicit_dataset then
    -- User is typing a full reference - try to list tables in that specific dataset
    local tables = M.get_tables(explicit_project, explicit_dataset)
    
    local results = {}
    for _, tbl in ipairs(tables) do
      if not explicit_table or tbl.name:lower():find(explicit_table:lower(), 1, true) then
        table.insert(results, {
          project = explicit_project,
          dataset = explicit_dataset,
          table = tbl.name,
          full_ref = tbl.full_ref
        })
        if #results >= limit then
          break
        end
      end
    end
    
    -- If searching for a partial table name and no results yet, try exact table
    if #results == 0 and explicit_table then
      -- Try to check if the exact table exists
      local exact_ref = explicit_project .. '.' .. explicit_dataset .. '.' .. explicit_table
      if M.table_exists(exact_ref) then
        table.insert(results, {
          project = explicit_project,
          dataset = explicit_dataset,
          table = explicit_table,
          full_ref = exact_ref
        })
      end
    end
    
    return results
  end
  
  -- Check for partial reference (dataset.table)
  local partial_dataset, partial_table = search_term:match('([^.]+)%.([^.]+)')
  
  local project = workspace.get_default_project()
  if not project then
    return {}
  end
  
  -- First try INFORMATION_SCHEMA if available
  local query = string.format([[
    SELECT 
      table_catalog as project,
      table_schema as dataset,
      table_name as table,
      CONCAT(table_catalog, '.', table_schema, '.', table_name) as full_ref
    FROM \`%s.region-US.INFORMATION_SCHEMA.TABLES\`
    WHERE (LOWER(table_name) LIKE LOWER('%%%s%%')
      OR LOWER(table_schema) LIKE LOWER('%%%s%%'))
      AND table_schema NOT IN ('INFORMATION_SCHEMA')
    ORDER BY table_schema, table_name
    LIMIT %d
  ]], project, search_term, search_term, limit)
  
  -- Escape the query properly for shell
  query = query:gsub('"', '\\"')
  local data, err = M.execute_bq("query --use_legacy_sql=false '" .. query .. "'")
  -- Debug output
  -- print("Query result:", vim.inspect(data))
  -- print("Query error:", vim.inspect(err))
  if not err and data and #data > 0 then
    return data
  end
  
  -- Fallback: Search through frequently used datasets
  local results = {}
  local datasets = workspace.get_frequent_datasets()
  
  -- Also add some common datasets
  table.insert(datasets, project .. ".scratch")
  table.insert(datasets, project .. ".staging")
  table.insert(datasets, project .. ".raw")
  
  for _, dataset_ref in ipairs(datasets) do
    local proj, ds = dataset_ref:match('([^.]+)%.([^.]+)')
    if not proj then
      proj = project
      ds = dataset_ref
    end
    
    -- List tables in this dataset
    local tbls = M.get_tables(proj, ds)
    for _, tbl in ipairs(tbls) do
      if tbl.name:lower():find(search_term:lower(), 1, true) then
        table.insert(results, {
          project = proj,
          dataset = ds,
          table = tbl.name,
          full_ref = tbl.full_ref
        })
        
        if #results >= limit then
          break
        end
      end
    end
    
    if #results >= limit then
      break
    end
  end
  
  return results
end

-- Extract tables from current buffer
function M.extract_tables_from_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local tables = {}
  local seen = {}
  
  for _, line in ipairs(lines) do
    -- Match table references with backticks
    for match in line:gmatch('`([^`]+%.[^`]+%.[^`]+)`') do
      if not seen[match] then
        seen[match] = true
        table.insert(tables, match)
      end
    end
    for match in line:gmatch('`([^`]+%.[^`]+)`') do
      if not seen[match] then
        seen[match] = true
        table.insert(tables, match)
      end
    end
  end
  
  return tables
end

-- Validate table exists
function M.table_exists(table_ref)
  local schema = M.get_schema(table_ref)
  return #schema > 0
end

return M