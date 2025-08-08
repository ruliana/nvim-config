-- BigQuery completion source for nvim-cmp
local M = {}
local api = require('bigquery.api')
local mru = require('bigquery.mru')
local workspace = require('bigquery.workspace')
local cache = require('bigquery.cache')

local source = {}

-- Check if source is available
function source:is_available()
  return vim.bo.filetype == 'sql' or vim.bo.filetype == 'bigquery'
end

-- Get trigger characters
function source:get_trigger_characters()
  return { '.', '`' }
end

-- Get keyword pattern
function source:get_keyword_pattern()
  return [[\k\+]]
end

-- Detect completion context
local function detect_context(line, col)
  -- Check for various SQL contexts
  local patterns = {
    -- Table contexts
    { pattern = 'from%s+`?([^`%s]*)$', type = 'table', prefix_match = 1 },
    { pattern = 'join%s+`?([^`%s]*)$', type = 'table', prefix_match = 1 },
    { pattern = 'into%s+`?([^`%s]*)$', type = 'table', prefix_match = 1 },
    { pattern = 'update%s+`?([^`%s]*)$', type = 'table', prefix_match = 1 },
    { pattern = 'table%s+`?([^`%s]*)$', type = 'table', prefix_match = 1 },
    
    -- Field contexts (after table reference)
    { pattern = '`([^`]+%.[^`]+%.[^`]+)`%.([^%s]*)$', type = 'field', table_match = 1, prefix_match = 2 },
    { pattern = '`([^`]+%.[^`]+)`%.([^%s]*)$', type = 'field', table_match = 1, prefix_match = 2 },
    { pattern = 'select%s+([^,]*)$', type = 'field_or_func', prefix_match = 1 },
    { pattern = 'where%s+([^%s]*)$', type = 'field', prefix_match = 1 },
    { pattern = 'group%s+by%s+([^,]*)$', type = 'field', prefix_match = 1 },
    { pattern = 'order%s+by%s+([^,]*)$', type = 'field', prefix_match = 1 },
    
    -- Dataset context (after project.)
    { pattern = 'from%s+`?([^`.]+)%.([^`%s]*)$', type = 'dataset', project_match = 1, prefix_match = 2 },
    { pattern = 'join%s+`?([^`.]+)%.([^`%s]*)$', type = 'dataset', project_match = 1, prefix_match = 2 },
  }
  
  for _, p in ipairs(patterns) do
    local matches = {line:match(p.pattern)}
    if #matches > 0 then
      local context = { type = p.type }
      
      if p.prefix_match then
        context.prefix = matches[p.prefix_match] or ''
      end
      
      if p.table_match then
        context.table = matches[p.table_match]
      end
      
      if p.project_match then
        context.project = matches[p.project_match]
      end
      
      return context
    end
  end
  
  return nil
end

-- Create completion item
local function create_item(label, kind, detail, sort_priority, documentation)
  return {
    label = label,
    kind = kind,
    detail = detail,
    sortText = string.format("%02d_%s", sort_priority, label),
    documentation = documentation
  }
end

-- Get table completions
local function get_table_completions(prefix)
  local items = {}
  local cmp_kinds = require('cmp').lsp.CompletionItemKind
  
  -- 1. MRU tables (highest priority)
  local mru_tables = mru.get_tables(10)
  for i, entry in ipairs(mru_tables) do
    if not prefix or entry.ref:match('^' .. vim.pesc(prefix)) then
      table.insert(items, create_item(
        entry.ref,
        cmp_kinds.Value,
        string.format("📜 Used %d times", entry.use_count),
        1,
        string.format("Last used: %s", os.date("%Y-%m-%d %H:%M", entry.last_used))
      ))
    end
  end
  
  -- 2. Pinned tables
  local pinned = workspace.get_pinned_tables()
  for i, table_ref in ipairs(pinned) do
    if not prefix or table_ref:match('^' .. vim.pesc(prefix)) then
      table.insert(items, create_item(
        table_ref,
        cmp_kinds.Constant,
        "📌 Pinned",
        2
      ))
    end
  end
  
  -- 3. Frequent datasets (if no specific prefix)
  if not prefix or prefix == '' then
    local datasets = workspace.get_frequent_datasets()
    for _, dataset in ipairs(datasets) do
      table.insert(items, create_item(
        dataset .. '.',
        cmp_kinds.Module,
        "📁 Dataset",
        3
      ))
    end
  end
  
  return items
end

-- Get dataset completions for a project
local function get_dataset_completions(project, prefix)
  local items = {}
  local cmp_kinds = require('cmp').lsp.CompletionItemKind
  
  local datasets = api.get_datasets(project)
  for _, dataset in ipairs(datasets) do
    if not prefix or dataset:match('^' .. vim.pesc(prefix)) then
      local full_ref = project .. '.' .. dataset
      table.insert(items, create_item(
        full_ref,
        cmp_kinds.Module,
        "📁 Dataset",
        5
      ))
    end
  end
  
  return items
end

-- Get field completions for a table
local function get_field_completions(table_ref, prefix)
  local items = {}
  local cmp_kinds = require('cmp').lsp.CompletionItemKind
  
  local fields = api.get_schema(table_ref)
  for _, field in ipairs(fields) do
    if not prefix or field.name:match('^' .. vim.pesc(prefix)) then
      local detail = field.type
      if field.mode and field.mode ~= 'NULLABLE' then
        detail = detail .. ' (' .. field.mode .. ')'
      end
      
      table.insert(items, create_item(
        field.name,
        cmp_kinds.Field,
        detail,
        10,
        field.description
      ))
    end
  end
  
  return items
end

-- Complete function
function source:complete(params, callback)
  local line = params.context.cursor_before_line
  local col = params.context.cursor.col
  
  local context = detect_context(line, col)
  
  if not context then
    callback({})
    return
  end
  
  local items = {}
  
  if context.type == 'table' then
    items = get_table_completions(context.prefix)
    
    -- Load more tables asynchronously if needed
    if #items < 5 and context.prefix and #context.prefix > 2 then
      vim.defer_fn(function()
        api.search_tables(context.prefix, 20)
      end, 100)
    end
    
  elseif context.type == 'dataset' and context.project then
    items = get_dataset_completions(context.project, context.prefix)
    
  elseif context.type == 'field' and context.table then
    items = get_field_completions(context.table, context.prefix)
    
    -- Prefetch schema asynchronously if not cached
    api.get_schema_async(context.table, function(fields)
      -- Schema will be cached for next completion
    end)
  end
  
  callback(items)
end

-- Get source name
function source:get_debug_name()
  return 'bigquery'
end

-- Create and return source
function M.new()
  return setmetatable({}, { __index = source })
end

return M