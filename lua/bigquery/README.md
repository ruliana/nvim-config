# BigQuery Neovim Plugin

A Neovim plugin for running BigQuery queries directly from your editor.

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