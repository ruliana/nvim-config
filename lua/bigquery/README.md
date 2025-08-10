# BigQuery Neovim Plugin

A Neovim plugin for running BigQuery queries directly from your editor.

## Architecture

### Query Execution Flow

```mermaid
graph TD
    A[User Triggers Command] -->|BQRun/BQRunSelection/BQPrompt| B[init.lua]
    
    B --> C{Query Source}
    C -->|BQRun| D[input.get_query_at_cursor]
    C -->|BQRun fallback| E[input.get_buffer_query]
    C -->|BQRunSelection| F[input.get_visual_selection]
    C -->|BQPrompt| G[input.prompt_for_query]
    
    D --> H[Query Extraction Logic]
    E --> H
    F --> H
    G --> H
    
    H -->|Extract query text| I[executor.execute]
    
    I --> J[Build bq command]
    J -->|Add flags: format, max_rows, project_id| K[Command Array]
    
    I --> L[Start Progress Timer]
    L -->|Show spinner + elapsed time| M["'BigQuery query running...' message<br/>vim.api.nvim_echo()"]
    
    I --> N[vim.fn.jobstart]
    N -->|Send query via stdin| O[vim.fn.chansend]
    O --> P[vim.fn.chanclose]
    
    N --> Q{Job Callbacks}
    Q -->|on_stdout| R[Collect output_lines]
    Q -->|on_stderr| S[Collect error_lines<br/>Filter progress messages]
    Q -->|on_exit| T{Exit Code?}
    
    T -->|0: Success| U[Stop Progress Timer]
    T -->|Non-zero: Error| U
    U --> V[Clear progress message]
    
    T -->|Success| W{Output Type?}
    W -->|DDL Statement| X[Show notification]
    W -->|Query Results| Y[display.show_results]
    W -->|No Output| Z[Show "no results" message]
    
    T -->|Error| AA[executor.handle_error]
    AA --> AB[display.show_error]
    
    Y --> AC[Create/Reuse Results Buffer]
    AC --> AD[Open Split Window]
    AD --> AE[Display Results]
    
    AB --> AF[Create Error Buffer]
    AF --> AG[Open Split Window]
    AG --> AH[Display Error]
```

### Key Components

- **input.lua**: Handles query extraction from buffer, visual selection, or prompt
  - `get_query_at_cursor()`: Extracts query at cursor position using semicolon delimiters
  - `get_buffer_query()`: Gets entire buffer content as query
  - `get_visual_selection()`: Extracts visually selected text
  - `prompt_for_query()`: Shows input prompt for query

- **executor.lua**: Manages query execution and job control
  - `execute()`: Main execution function that builds command and manages async job
  - Progress indicator using timer (100ms intervals) with spinner animation
  - Shows "BigQuery query running..." message via `vim.api.nvim_echo()`
  - `handle_error()`: Processes and categorizes BigQuery errors

- **display.lua**: Handles result and error display
  - `show_results()`: Creates results buffer and displays query output
  - `show_error()`: Creates error buffer with formatted error messages
  - Reuses existing "BigQuery Results" buffer when available

## Features

- Run entire SQL buffer or visual selection
- Support for BigQuery pipe syntax (`|>`)
- Multiple output formats (table, JSON, CSV)
- Asynchronous query execution
- Results displayed in split buffer
- Project auto-detection from environment or gcloud config

## Usage

### Commands

- `:BQRun` - Run entire buffer as query
- `:BQRunSelection` - Run selected lines as query
- `:BQPrompt` - Enter query via prompt
- `:BQFormat` - Cycle through output formats

### Keybindings

- `<leader>bq` - Run query (buffer or selection based on mode)
- `<leader>bQ` - Run query from prompt
- `<leader>bf` - Cycle output format

### In Results Buffer

- `q` or `<Esc>` - Close results
- `gq` - View original query in floating window

## Configuration

```lua
require("bigquery").setup({
  default_project = nil,        -- Auto-detected from env or gcloud
  max_results = 1000,           -- Max rows to return
  format = "table",             -- Output format: table/json/csv
  split_direction = "below",    -- Where to open results
  split_size = 15,              -- Height of results window
  use_legacy_sql = false,       -- Use standard SQL
  show_query_time = true,       -- Display execution time
  auto_format = true,           -- Auto-format JSON results
})
```

## Requirements

- Neovim 0.8+
- Google Cloud SDK (`gcloud` and `bq` CLI tools)
- Authenticated gcloud (`gcloud auth login`)

## Example Queries

```sql
-- Simple query
select current_timestamp() as time

-- Pipe syntax
from `project.dataset.table`
|> where status = 'active'
|> select name, created_at
|> limit 10

-- Multi-line with comments
-- Get recent orders
from `sales.orders`
|> where date > current_date() - 7
|> order by created_at desc
|> limit 100
```