-- BigQuery API wrapper using bq CLI
local M = {}
local cache = require('bigquery.cache')
local workspace = require('bigquery.workspace')

-- Execute bq command and return parsed JSON
function M.execute_bq(cmd, parse_json)
  parse_json = parse_json ~= false  -- Default to true
  
  local full_cmd = 'bq ' .. cmd
  if parse_json then
    full_cmd = full_cmd .. ' --format=json'
  end
  
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
  local full_cmd = 'bq ' .. cmd .. ' --format=json'
  
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
    for _, table in ipairs(data or {}) do
      local table_id = table.id or table.tableId
      if table_id then
        -- Extract just the table name
        table_id = table_id:match('([^:%.]+)$')
        if table_id and not workspace.should_ignore(table_id) then
          table.insert(tables, {
            name = table_id,
            type = table.type or 'TABLE',
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
  local project, dataset, table = table_ref:match('([^.]+)%.([^.]+)%.([^.]+)')
  if not project or not dataset or not table then
    -- Try 2-part reference with default project
    dataset, table = table_ref:match('([^.]+)%.([^.]+)')
    project = workspace.get_default_project()
    if not dataset or not table or not project then
      return {}
    end
  end
  
  return cache.get('schemas', table_ref, function()
    local full_ref = project .. ':' .. dataset .. '.' .. table
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
  local project, dataset, table = table_ref:match('([^.]+)%.([^.]+)%.([^.]+)')
  if not project or not dataset or not table then
    dataset, table = table_ref:match('([^.]+)%.([^.]+)')
    project = workspace.get_default_project()
    if not dataset or not table or not project then
      callback({})
      return
    end
  end
  
  local full_ref = project .. ':' .. dataset .. '.' .. table
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

-- Search for tables (using INFORMATION_SCHEMA)
function M.search_tables(search_term, limit)
  limit = limit or 50
  local project = workspace.get_default_project()
  if not project then
    return {}
  end
  
  local query = string.format([[
    SELECT 
      table_catalog as project,
      table_schema as dataset,
      table_name as table,
      CONCAT(table_catalog, '.', table_schema, '.', table_name) as full_ref
    FROM `%s.region-US.INFORMATION_SCHEMA.TABLES`
    WHERE table_name LIKE '%%%s%%'
      AND table_schema NOT IN ('INFORMATION_SCHEMA')
    ORDER BY table_schema, table_name
    LIMIT %d
  ]], project, search_term, limit)
  
  local data, err = M.execute_bq('query --use_legacy_sql=false "' .. query .. '"')
  if err then
    return {}
  end
  
  return data or {}
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