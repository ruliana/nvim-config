-- BigQuery table browser using Telescope
local M = {}

local api = require('bigquery.api')
local mru = require('bigquery.mru')
local workspace = require('bigquery.workspace')

-- Constants
local CONSTANTS = {
  -- Search configuration
  MIN_SEARCH_LENGTH = 3,
  GLOBAL_SEARCH_MIN_LENGTH = 4,
  SEARCH_DEBOUNCE_MS = 1000,
  DEFAULT_SEARCH_LIMIT = 50,
  MAX_SEARCH_RESULTS = 100,
  
  -- Display configuration
  MRU_DISPLAY_LIMIT = 20,
  SPINNER_FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  SEPARATOR_LINE = "────────────────────────────────────",
  
  -- Category icons
  CATEGORY_ICONS = {
    Recent = "󱋡",
    Pinned = "📌",
    Dataset = "📁",
    Table = "📊",
    Help = "💡",
    Suggested = "🔍",
    Loading = "⏱",
    Status = "ℹ",
    Info = "ℹ",
    Separator = "─"
  },
  
  -- Messages
  MESSAGES = {
    TELESCOPE_REQUIRED = "Telescope is required for table browsing",
    TYPE_MORE_CHARS = "💡 Type at least 4 characters to search across all projects",
    SEARCHING_WAIT = "⏳ Waiting 1 second before searching...",
    SEARCHING_ACTIVE = "🔍 Searching BigQuery for '%s'...",
    NO_RESULTS = "No tables found matching: %s",
    SEARCH_MIN_CHARS = "Enter at least 3 characters to search"
  }
}

-- Helper function to create a help/status entry
local function create_help_entry(value, display, ordinal, category)
  return {
    value = value,
    display = display,
    ordinal = ordinal or "zzz_help",
    category = category or "Help",
    is_help = true
  }
end

-- Helper function to create a separator entry
local function create_separator()
  return {
    value = "---",
    display = CONSTANTS.SEPARATOR_LINE,
    ordinal = "yyy_separator",
    category = "Separator",
    is_help = true
  }
end

-- Helper function to combine results arrays
local function combine_results(base, additional)
  local combined = vim.deepcopy(base)
  for _, item in ipairs(additional or {}) do
    table.insert(combined, item)
  end
  return combined
end

-- Prepare initial table list with MRU, pinned, and datasets
local function prepare_initial_tables()
  local tables = {}
  local seen = {}
  
  -- 1. Add MRU tables
  local mru_tables = mru.get_tables(CONSTANTS.MRU_DISPLAY_LIMIT)
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
    table.insert(tables, create_help_entry(
      "[Help] Run a query to populate MRU",
      "💡 Run a query with <leader>bq to populate recent tables",
      "zzz_help_1"
    ))
    
    table.insert(tables, create_help_entry(
      "[Help] Create .bqrc.json",
      "💡 Run :BQCreateConfig to create workspace config",
      "zzz_help_2"
    ))
    
    table.insert(tables, create_help_entry(
      "[Help] Pin tables",
      "💡 Use <leader>bp on a table reference to pin it",
      "zzz_help_3"
    ))
    
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
  
  return tables, seen
end

-- Create the telescope displayer for table entries
local function create_table_displayer()
  local entry_display = require('telescope.pickers.entry_display')
  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 8 },
      { remaining = true },
      { width = 10 }
    }
  }
  
  local function make_display(entry)
    local icon = CONSTANTS.CATEGORY_ICONS[entry.category] or CONSTANTS.CATEGORY_ICONS.Table
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
  
  return displayer, make_display
end

-- Setup picker mappings
local function setup_picker_mappings(dynamic_finder)
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  return function(prompt_bufnr, map)
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
    
    -- Add custom mapping to pin/unpin tables using Alt-p
    map('i', '<M-p>', function()
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
    
    -- Add mapping to search for more tables using Alt-s
    map('i', '<M-s>', function()
      local current_picker = action_state.get_current_picker(prompt_bufnr)
      local search_term = current_picker:_get_prompt()
      actions.close(prompt_bufnr)
      
      if search_term and #search_term >= CONSTANTS.MIN_SEARCH_LENGTH then
        M.search_tables(search_term)
      else
        vim.notify(CONSTANTS.MESSAGES.SEARCH_MIN_CHARS, vim.log.levels.WARN)
      end
    end)
    
    return true
  end
end

-- Create search state manager
local function create_search_state()
  return {
    cache = {},
    in_progress = {},
    spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
    spinner_idx = 1,
    current_picker = nil
  }
end

-- Browse tables with Telescope
function M.browse_tables()
  local ok, telescope = pcall(require, 'telescope')
  if not ok then
    vim.notify(CONSTANTS.MESSAGES.TELESCOPE_REQUIRED, vim.log.levels.ERROR)
    return
  end
  
  -- Ensure workspace config is loaded
  workspace.reload()
  
  local finders = require('telescope.finders')
  local pickers = require('telescope.pickers')
  local conf = require('telescope.config').values
  
  -- Prepare initial tables
  local tables = prepare_initial_tables()
  
  -- Create displayer
  local displayer, make_display = create_table_displayer()
  
  -- Initialize search state
  local search_state = create_search_state()
  
  -- Create a dynamic finder that can search BigQuery when needed
  local dynamic_finder = finders.new_dynamic {
    fn = function(prompt)
      
      -- If prompt is empty, return cached tables
      if not prompt or #prompt == 0 then
        search_state.cache = {}  -- Clear cache when prompt is cleared
        search_state.in_progress = {}
        return tables
      end
      
      -- If prompt is too short for any search
      if #prompt < CONSTANTS.MIN_SEARCH_LENGTH then
        return {
          create_help_entry(
            "[Type more]",
            CONSTANTS.MESSAGES.TYPE_MORE_CHARS
          )
        }
      end
      
      -- First, filter local tables (Recent, Pinned, etc.)
      local filtered = {}
      for _, item in ipairs(tables) do
        if item.value:lower():find(prompt:lower(), 1, true) then
          table.insert(filtered, item)
        end
      end
      
      -- Check if we already have cached search results for this prompt
      if search_state.cache[prompt] then
        -- Combine local matches with cached search results
        return combine_results(filtered, search_state.cache[prompt])
      end
      
      -- Cancel any pending or in-progress searches for different prompts
      for old_prompt, _ in pairs(search_state.in_progress) do
        if old_prompt ~= prompt then
          search_state.in_progress[old_prompt] = false
        end
      end
      
      -- Check if search is already in progress for this prompt
      if search_state.in_progress[prompt] then
        search_state.spinner_idx = (search_state.spinner_idx % #search_state.spinner_frames) + 1
        -- Return local matches plus loading indicator
        local results = vim.deepcopy(filtered)
        table.insert(results, create_help_entry(
          "[Loading...]",
          search_state.spinner_frames[search_state.spinner_idx] .. " Searching BigQuery for: " .. prompt .. " ...",
          "zzz_loading",
          "Loading"
        ))
        return results
      end
      
      -- Mark search as in progress
      search_state.in_progress[prompt] = true
      
      -- Function to process search results (defined first so it's in scope)
      local function process_search_results(search_prompt, search_results, error_msg)
        if error_msg then
          -- Handle error case
          local results = {
            create_help_entry(
              "[Error]",
              "❌ " .. error_msg,
              "zzz_error",
              "Error"
            )
          }
          search_state.cache[search_prompt] = results
          search_state.in_progress[search_prompt] = false
          vim.schedule(function()
            if search_state.current_picker then
              search_state.current_picker:refresh(dynamic_finder, { reset_prompt = false })
            end
          end)
          return
        end
        
        local results = {}
        for _, result in ipairs(search_results or {}) do
          
          -- Handle both string and table results
          local ref = type(result) == "string" and result or result.full_ref
          if ref then
            table.insert(results, {
              value = ref,
              display = "[Found] " .. ref,
              ordinal = ref,
              category = "Search"
            })
          end
        end
        
        if #results == 0 then
          table.insert(results, create_help_entry(
            "[No results found]",
            string.format(CONSTANTS.MESSAGES.NO_RESULTS, prompt),
            "zzz_no_results",
            "Info"
          ))
        end
        
        -- If no results and prompt doesn't include dots, add help message
        if #results == 0 and not prompt:match('%.') then
          results = {
            create_help_entry(
              "[No results]",
              "❌ No tables found with '" .. prompt .. "'",
              "zzz_no_results_1",
              "Info"
            ),
            create_help_entry(
              "[Tip]",
              "💡 Try: project.dataset.table or dataset.table",
              "zzz_no_results_2"
            ),
            create_help_entry(
              "[Example]",
              "📝 e.g. sdp-prd-cti-data.intermediate." .. prompt,
              "zzz_no_results_3"
            )
          }
        end
        
        -- Cache only the search results (not local matches)
        search_state.cache[search_prompt] = results
        search_state.in_progress[search_prompt] = false
        
        -- Trigger picker refresh to show combined results
        vim.schedule(function()
          if search_state.current_picker then
            search_state.current_picker:refresh(dynamic_finder, { reset_prompt = false })
          end
        end)
      end
      
      -- Start async search in background job
      local function start_background_search()
        
        -- Show notification that search is starting
        vim.notify("🔍 Searching BigQuery for: " .. prompt, vim.log.levels.INFO)
        
        -- Run search in a truly async way
        if prompt:match('%.') then
          -- Has dots - use targeted search (this will be synchronous but fast)
          vim.defer_fn(function()
            local ok, search_results = pcall(api.search_tables, prompt, CONSTANTS.DEFAULT_SEARCH_LIMIT)
            if not ok then
              process_search_results(prompt, nil, "Search failed: " .. tostring(search_results))
            else
              process_search_results(prompt, search_results)
            end
          end, 10)
          return
        else
          -- No dots - use global search if long enough
          if #prompt >= CONSTANTS.GLOBAL_SEARCH_MIN_LENGTH then
            vim.defer_fn(function()
              local ok, search_results = pcall(api.global_search_datasets, prompt, CONSTANTS.DEFAULT_SEARCH_LIMIT)
              if not ok then
                process_search_results(prompt, nil, "Search failed: " .. tostring(search_results))
              else
                process_search_results(prompt, search_results)
              end
            end, 10)
            return
          else
            search_state.in_progress[prompt] = false
            return
          end
        end
      end
      
      -- Start the background search with delay for debouncing (1 second)
      vim.defer_fn(function()
        -- Check if this prompt is still the one we want to search for
        -- (user might have continued typing)
        if search_state.in_progress[prompt] then
          start_background_search()
        end
      end, CONSTANTS.SEARCH_DEBOUNCE_MS)  -- Wait after user stops typing
      
      -- Return local matches plus loading indicator immediately
      local immediate_results = vim.deepcopy(filtered)
      
      -- Add a visual separator and loading indicator
      if #immediate_results > 0 then
        table.insert(immediate_results, create_separator())
      end
      
      table.insert(immediate_results, create_help_entry(
        "[Searching...]",
        CONSTANTS.MESSAGES.SEARCHING_WAIT,
        "zzz_searching_1",
        "Status"
      ))
      
      -- Update the status after 1 second to show actual searching
      vim.defer_fn(function()
        if search_state.in_progress[prompt] and search_state.current_picker then
          -- Update to show we're actually searching now
          vim.schedule(function()
            local updated_results = vim.deepcopy(filtered)
            if #updated_results > 0 then
              table.insert(updated_results, create_separator())
            end
            table.insert(updated_results, create_help_entry(
              "[Searching...]",
              string.format(CONSTANTS.MESSAGES.SEARCHING_ACTIVE, prompt),
              "zzz_searching_2",
              "Status"
            ))
            if search_state.current_picker then
              search_state.current_picker:refresh(dynamic_finder, { reset_prompt = false })
            end
          end)
        end
      end, CONSTANTS.SEARCH_DEBOUNCE_MS)
      
      return immediate_results
    end,
    entry_maker = function(entry)
      if type(entry) == "string" then
        return {
          value = entry,
          display = entry,
          ordinal = entry
        }
      end
      
      local display_str = entry.value
      if entry.category then
        display_str = "[" .. entry.category .. "] " .. display_str
      end
      if entry.use_count then
        display_str = display_str .. " (" .. entry.use_count .. "x)"
      end
      
      return {
        value = entry.value,
        display = display_str,
        ordinal = entry.ordinal or entry.value,
        category = entry.category,
        is_dataset = entry.is_dataset,
        is_help = entry.is_help,
        use_count = entry.use_count
      }
    end
  }
  
  search_state.current_picker = pickers.new({}, {
    prompt_title = "BigQuery Tables (type project.dataset.table for cross-project)",
    finder = dynamic_finder,
    sorter = conf.generic_sorter({}),
    attach_mappings = setup_picker_mappings(dynamic_finder)
  })
  
  search_state.current_picker:find()
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
  local ok, tables = pcall(api.get_tables, project, dataset)
  
  if not ok then
    vim.notify("Failed to load tables: " .. tostring(tables), vim.log.levels.ERROR)
    return
  end
  
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
  local ok, results = pcall(api.search_tables, search_term, CONSTANTS.MAX_SEARCH_RESULTS)
  
  if not ok then
    vim.notify("Search failed: " .. tostring(results), vim.log.levels.ERROR)
    return
  end
  
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