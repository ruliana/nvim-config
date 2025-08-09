-- Discover frequently used projects and datasets from user's BigQuery usage
local M = {}

local api = require('bigquery.api')
local workspace = require('bigquery.workspace')

-- Query user's recent BigQuery usage to find frequent projects and datasets
function M.discover_frequent_usage()
  -- Show disclaimer about time
  vim.notify("⏱️  This command queries your BigQuery usage history and takes ~1 minute to complete", vim.log.levels.WARN)
  
  -- Create a floating window for progress
  local buf = vim.api.nvim_create_buf(false, true)
  local width = 60
  local height = 3
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
  })
  
  -- Progress indicator
  local spinner_frames = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
  local spinner_idx = 1
  
  local function update_progress(message)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      " " .. spinner_frames[spinner_idx] .. " " .. message,
      "",
      " Press Ctrl-C to cancel"
    })
    spinner_idx = (spinner_idx % #spinner_frames) + 1
  end
  
  -- Start spinner animation
  local timer = vim.loop.new_timer()
  timer:start(0, 100, vim.schedule_wrap(function()
    if vim.api.nvim_win_is_valid(win) then
      update_progress("Querying INFORMATION_SCHEMA...")
    else
      timer:stop()
    end
  end))
  
  -- Get user email
  local user_email = vim.fn.system('gcloud config get-value account 2>/dev/null'):gsub('%s+', '')
  if not user_email or user_email == '' then
    vim.api.nvim_win_close(win, true)
    timer:stop()
    vim.notify("Could not determine user email from gcloud", vim.log.levels.ERROR)
    return
  end
  
  -- Query for frequently used projects and datasets
  local query = string.format([[
    WITH recent_tables AS (
      SELECT 
        table_ref.project_id,
        table_ref.dataset_id,
        COUNT(*) as usage_count
      FROM `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`,
        UNNEST(referenced_tables) as table_ref
      WHERE DATE(creation_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
        AND user_email = '%s'
        AND statement_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'MERGE')
        AND table_ref.dataset_id NOT IN ('INFORMATION_SCHEMA')
      GROUP BY 1, 2
      HAVING usage_count >= 5  -- At least 5 uses in the past month
    ),
    project_stats AS (
      SELECT 
        project_id,
        ARRAY_AGG(
          STRUCT(dataset_id as dataset, usage_count) 
          ORDER BY usage_count DESC 
          LIMIT 5
        ) as top_datasets,
        SUM(usage_count) as total_usage
      FROM recent_tables
      GROUP BY 1
      ORDER BY total_usage DESC
      LIMIT 10
    )
    SELECT 
      project_id,
      top_datasets,
      total_usage
    FROM project_stats
    ORDER BY total_usage DESC
  ]], user_email)
  
  -- Execute the query (run in background)
  vim.defer_fn(function()
    local result_json = api.execute_bq(
      string.format("query --use_legacy_sql=false '%s'", query:gsub("'", "\\'")),
      true
    )
    
    -- Stop spinner and close progress window
    timer:stop()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    
    if not result_json or #result_json == 0 then
      vim.notify("No usage data found for the past 30 days", vim.log.levels.WARN)
      return
    end
  
    -- Process results
    local search_targets = {}
    local all_datasets = {}
    local seen_datasets = {}
    
    for _, row in ipairs(result_json) do
      local project = row.project_id
      local datasets = {}
      
      if row.top_datasets then
        for _, ds in ipairs(row.top_datasets) do
          if ds.dataset then
            table.insert(datasets, ds.dataset)
            
            -- Track unique datasets across all projects
            if not seen_datasets[ds.dataset] then
              seen_datasets[ds.dataset] = true
              table.insert(all_datasets, ds.dataset)
            end
          end
        end
      end
      
      if #datasets > 0 then
        table.insert(search_targets, {
          project = project,
          datasets = datasets
        })
      end
    end
    
    -- Update configuration
    local config = workspace.config or workspace.load()
    
    -- Merge with existing search_targets (keeping manual additions)
    local existing_projects = {}
    for _, target in ipairs(config.search_targets or {}) do
      existing_projects[target.project] = target
    end
    
    -- Add discovered projects
    for _, target in ipairs(search_targets) do
      if existing_projects[target.project] then
        -- Merge datasets
        local existing_ds = {}
        for _, ds in ipairs(existing_projects[target.project].datasets) do
          existing_ds[ds] = true
        end
        
        for _, ds in ipairs(target.datasets) do
          if not existing_ds[ds] then
            table.insert(existing_projects[target.project].datasets, ds)
          end
        end
      else
        -- Add new project
        existing_projects[target.project] = target
      end
    end
    
    -- Convert back to array
    local merged_targets = {}
    for _, target in pairs(existing_projects) do
      table.insert(merged_targets, target)
    end
    
    -- Sort by project name for consistency
    table.sort(merged_targets, function(a, b)
      return a.project < b.project
    end)
    
    config.search_targets = merged_targets
    
    -- Update default_search_datasets with commonly used datasets
    local existing_default = {}
    for _, ds in ipairs(config.default_search_datasets or {}) do
      existing_default[ds] = true
    end
    
    for _, ds in ipairs(all_datasets) do
      if not existing_default[ds] then
        table.insert(config.default_search_datasets, ds)
      end
    end
  
    -- Save updated configuration
    workspace.config = config
    if workspace.save() then
      vim.notify(string.format(
        "✅ Updated .bqrc.json with %d projects and %d unique datasets from your usage",
        #merged_targets,
        #all_datasets
      ), vim.log.levels.INFO)
    else
      vim.notify("Failed to save configuration", vim.log.levels.ERROR)
    end
  end, 100)  -- Small delay to let UI update
end

-- Query for most frequently used tables
function M.discover_frequent_tables()
  vim.notify("Discovering your frequently used tables...", vim.log.levels.INFO)
  
  -- Get user email
  local user_email = vim.fn.system('gcloud config get-value account 2>/dev/null'):gsub('%s+', '')
  if not user_email or user_email == '' then
    vim.notify("Could not determine user email from gcloud", vim.log.levels.ERROR)
    return
  end
  
  -- Query for frequently used tables
  local query = string.format([[
    SELECT 
      CONCAT(table_ref.project_id, '.', table_ref.dataset_id, '.', table_ref.table_id) as table_ref,
      COUNT(*) as use_count
    FROM `region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT`,
      UNNEST(referenced_tables) as table_ref
    WHERE DATE(creation_time) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      AND user_email = '%s'
      AND statement_type IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'MERGE')
      AND table_ref.dataset_id NOT IN ('INFORMATION_SCHEMA')
    GROUP BY 1
    HAVING use_count >= 10  -- At least 10 uses in the past month
    ORDER BY use_count DESC
    LIMIT 20
  ]], user_email)
  
  -- Execute the query
  local result_json = api.execute_bq(
    string.format("query --use_legacy_sql=false '%s'", query:gsub("'", "\\'")),
    true
  )
  
  if not result_json or #result_json == 0 then
    vim.notify("No frequently used tables found", vim.log.levels.WARN)
    return
  end
  
  -- Update pinned tables
  local config = workspace.config or workspace.load()
  
  -- Keep existing pinned tables
  local existing_pinned = {}
  for _, table_ref in ipairs(config.pinned_tables or {}) do
    existing_pinned[table_ref] = true
  end
  
  -- Add frequently used tables that aren't already pinned
  local added = 0
  for _, row in ipairs(result_json) do
    if not existing_pinned[row.table_ref] and added < 10 then
      table.insert(config.pinned_tables, row.table_ref)
      added = added + 1
    end
  end
  
  -- Save if we added any tables
  if added > 0 then
    workspace.config = config
    if workspace.save() then
      vim.notify(string.format("Added %d frequently used tables to pinned list", added), vim.log.levels.INFO)
    end
  else
    vim.notify("No new tables to add to pinned list", vim.log.levels.INFO)
  end
end

return M