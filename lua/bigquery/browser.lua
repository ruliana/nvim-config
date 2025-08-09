-- BigQuery table browser using Telescope
local M = {}

local api = require('bigquery.api')
local mru = require('bigquery.mru')
local workspace = require('bigquery.workspace')
local cache = require('bigquery.cache')

-- Browse tables with Telescope
function M.browse_tables()
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.notify("Telescope is required for table browsing", vim.log.levels.ERROR)
    return
  end
  
  -- Ensure workspace config is loaded
  workspace.reload()
  
  local finders = require('telescope.finders')
  local pickers = require('telescope.pickers')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  local entry_display = require('telescope.pickers.entry_display')
  
  -- Prepare table list
  local tables = {}
  local seen = {}
  
  -- 1. Add MRU tables
  local mru_tables = mru.get_tables(20)
  for _, entry in ipairs(mru_tables) do
    if not seen[entry.ref] then
      seen[entry.ref] = true
      table.insert(tables, {
        value = entry.ref,
        display = entry.ref,
        ordinal = entry.ref,
        category = "Recent",
        use_count = entry.use_count,
        last_used = entry.last_used
      })
    end
  end
  
  -- 2. Add pinned tables
  local pinned_tables = workspace.get_pinned_tables()
  for _, table_ref in ipairs(pinned_tables) do
    if not seen[table_ref] then
      seen[table_ref] = true
      table.insert(tables, {
        value = table_ref,
        display = table_ref,
        ordinal = table_ref,
        category = "Pinned"
      })
    end
  end
  
  -- 3. Add frequent datasets (as expandable entries)
  local frequent_datasets = workspace.get_frequent_datasets()
  for _, dataset in ipairs(frequent_datasets) do
    if not seen[dataset] then
      seen[dataset] = true
      table.insert(tables, {
        value = dataset,
        display = dataset .. " [dataset]",
        ordinal = dataset,
        category = "Dataset",
        is_dataset = true
      })
    end
  end
  
  -- 4. If no tables yet, add help message and common datasets
  if #tables == 0 then
    -- Add help entries
    table.insert(tables, {
      value = "[Help] Run a query to populate MRU",
      display = "💡 Run a query with <leader>bq to populate recent tables",
      ordinal = "zzz_help_1",
      category = "Help",
      is_help = true
    })
    
    table.insert(tables, {
      value = "[Help] Create .bqrc.json",
      display = "💡 Run :BQCreateConfig to create workspace config",
      ordinal = "zzz_help_2", 
      category = "Help",
      is_help = true
    })
    
    table.insert(tables, {
      value = "[Help] Pin tables",
      display = "💡 Use <leader>bp on a table reference to pin it",
      ordinal = "zzz_help_3",
      category = "Help",
      is_help = true
    })
    
    -- Try to add some common datasets if we have a default project
    local default_project = workspace.get_default_project()
    if default_project then
      -- Common dataset patterns
      local common_datasets = {
        "scratch",
        "staging", 
        "raw",
        "intermediate",
        "reporting",
        "analytics"
      }
      
      for _, dataset_pattern in ipairs(common_datasets) do
        table.insert(tables, {
          value = default_project .. "." .. dataset_pattern,
          display = default_project .. "." .. dataset_pattern .. " [search]",
          ordinal = dataset_pattern,
          category = "Suggested",
          is_dataset = true
        })
      end
    end
  end
  
  -- Create displayer
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 8 },
      { remaining = true },
      { width = 10 }
    }
  }
  
  local function make_display(entry)
    local category_icon = {
      Recent = "󱋡",
      Pinned = "📌",
      Dataset = "📁",
      Table = "📊",
      Help = "💡",
      Suggested = "🔍"
    }
    
    local icon = category_icon[entry.category] or "📊"
    local display_text = entry.display or entry.value
    local extra = ""
    
    if entry.use_count then
      extra = string.format("(%dx)", entry.use_count)
    end
    
    return displayer {
      { icon, "TelescopeResultsIdentifier" },
      display_text,
      { extra, "TelescopeResultsComment" }
    }
  end
  
  pickers.new({}, {
    prompt_title = "BigQuery Tables",
    finder = finders.new_table {
      results = tables,
      entry_maker = function(entry)
        -- Simplified entry maker for debugging
        local display_str = entry.value
        if entry.category then
          display_str = "[" .. entry.category .. "] " .. display_str
        end
        if entry.use_count then
          display_str = display_str .. " (" .. entry.use_count .. "x)"
        end
        
        return {
          value = entry.value,
          display = display_str,  -- Use simple string instead of function
          ordinal = entry.ordinal or entry.value,  -- Ensure ordinal is set
          category = entry.category,
          is_dataset = entry.is_dataset,
          is_help = entry.is_help,
          use_count = entry.use_count
        }
      end
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          if selection.is_help then
            -- Don't insert help text
            return
          elseif selection.is_dataset then
            -- Expand dataset to show tables
            M.browse_dataset_tables(selection.value)
          else
            -- Insert table reference
            local pos = vim.api.nvim_win_get_cursor(0)
            local line = vim.api.nvim_get_current_line()
            local before = line:sub(1, pos[2])
            local after = line:sub(pos[2] + 1)
            
            -- Add backticks if not present
            local table_ref = selection.value
            if not table_ref:match('^`') then
              table_ref = '`' .. table_ref .. '`'
            end
            
            vim.api.nvim_set_current_line(before .. table_ref .. after)
            vim.api.nvim_win_set_cursor(0, {pos[1], pos[2] + #table_ref})
            
            -- Add to MRU
            mru.add(selection.value)
          end
        end
      end)
      
      -- Add custom mapping to pin/unpin tables
      map('i', '<C-p>', function()
        local selection = action_state.get_selected_entry()
        if selection and not selection.is_dataset then
          if selection.category == "Pinned" then
            workspace.unpin_table(selection.value)
            vim.notify("Unpinned: " .. selection.value, vim.log.levels.INFO)
          else
            workspace.pin_table(selection.value)
            vim.notify("Pinned: " .. selection.value, vim.log.levels.INFO)
          end
        end
      end)
      
      return true
    end
  }):find()
end

-- Browse tables in a specific dataset
function M.browse_dataset_tables(dataset_ref)
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.notify("Telescope is required for table browsing", vim.log.levels.ERROR)
    return
  end
  
  local finders = require('telescope.finders')
  local pickers = require('telescope.pickers')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  -- Parse dataset reference
  local project, dataset
  if dataset_ref:match('%.') then
    project, dataset = dataset_ref:match('([^.]+)%.([^.]+)')
  else
    project = workspace.get_default_project()
    dataset = dataset_ref
  end
  
  if not project or not dataset then
    vim.notify("Invalid dataset reference", vim.log.levels.ERROR)
    return
  end
  
  -- Get tables in dataset
  vim.notify("Loading tables from " .. dataset_ref .. "...", vim.log.levels.INFO)
  local tables = api.get_tables(project, dataset)
  
  if #tables == 0 then
    vim.notify("No tables found in " .. dataset_ref, vim.log.levels.WARN)
    return
  end
  
  pickers.new({}, {
    prompt_title = "Tables in " .. dataset_ref,
    finder = finders.new_table {
      results = tables,
      entry_maker = function(entry)
        return {
          value = entry.full_ref,
          display = entry.name .. " (" .. entry.type .. ")",
          ordinal = entry.name
        }
      end
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          -- Insert table reference
          local pos = vim.api.nvim_win_get_cursor(0)
          local line = vim.api.nvim_get_current_line()
          local before = line:sub(1, pos[2])
          local after = line:sub(pos[2] + 1)
          
          local table_ref = '`' .. selection.value .. '`'
          vim.api.nvim_set_current_line(before .. table_ref .. after)
          vim.api.nvim_win_set_cursor(0, {pos[1], pos[2] + #table_ref})
          
          -- Add to MRU
          mru.add(selection.value)
        end
      end)
      
      return true
    end
  }):find()
end

-- Search tables across all projects
function M.search_tables(search_term)
  search_term = search_term or vim.fn.input("Search tables: ")
  if search_term == "" then
    return
  end
  
  vim.notify("Searching for tables matching: " .. search_term, vim.log.levels.INFO)
  local results = api.search_tables(search_term, 100)
  
  if #results == 0 then
    vim.notify("No tables found matching: " .. search_term, vim.log.levels.WARN)
    return
  end
  
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    -- Fallback to quickfix list
    local qf_items = {}
    for _, result in ipairs(results) do
      table.insert(qf_items, {
        text = result.full_ref,
        filename = "",
        lnum = 1,
        col = 1
      })
    end
    vim.fn.setqflist(qf_items, 'r')
    vim.cmd('copen')
    return
  end
  
  -- Use Telescope if available
  local finders = require('telescope.finders')
  local pickers = require('telescope.pickers')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  pickers.new({}, {
    prompt_title = "Search Results: " .. search_term,
    finder = finders.new_table {
      results = results,
      entry_maker = function(entry)
        return {
          value = entry.full_ref,
          display = entry.full_ref,
          ordinal = entry.full_ref
        }
      end
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        
        if selection then
          -- Insert table reference
          local pos = vim.api.nvim_win_get_cursor(0)
          local line = vim.api.nvim_get_current_line()
          local before = line:sub(1, pos[2])
          local after = line:sub(pos[2] + 1)
          
          local table_ref = '`' .. selection.value .. '`'
          vim.api.nvim_set_current_line(before .. table_ref .. after)
          vim.api.nvim_win_set_cursor(0, {pos[1], pos[2] + #table_ref})
          
          -- Add to MRU
          mru.add(selection.value)
        end
      end)
      
      return true
    end
  }):find()
end

return M