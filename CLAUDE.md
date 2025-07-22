# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup and Installation Commands

### Initial Setup
```bash
# Run the Python environment setup script
./setup-python.sh
```

This script:
- Installs all Neovim plugins via Lazy.nvim
- Installs Mason tools (basedpyright, ruff, debugpy, mypy)
- Verifies installations

### Manual Tool Management
```bash
# Launch Neovim and install/update plugins
nvim --headless -c "Lazy! sync" -c "qa"

# Install specific Mason tools
nvim --headless -c "MasonInstall basedpyright ruff debugpy mypy" -c "qa"

# Update TreeSitter parsers
nvim --headless -c "TSUpdate" -c "qa"
```

## Architecture Overview

This is a Python-focused Neovim configuration built on Lazy.nvim with the following key components:

### Plugin Management
- **Lazy.nvim**: Plugin manager with lazy loading
- Plugins organized in `lua/plugins/` with modular configuration files
- Auto-installs plugins and ensures required tools are available
- **Which-key**: Keybinding discovery and organization

### Language Support Architecture
- **LSP Stack**: BasedPyright (type checking) + Ruff (linting/formatting)
- **Debugging**: nvim-dap with Python adapter and UI
- **Completion**: nvim-cmp with LSP, snippets, buffer, and path sources
- **UV Integration**: Built-in support for UV package management
- **TreeSitter**: Syntax highlighting and text objects for Python, Lua, Markdown, JSON, YAML, HTML, Bash

### Key Integrations
- **UV Package Manager**: Native commands for Python project management
- **Auto-detection**: Automatically restarts LSP when changing directories
- **Virtual Environment**: Detects pyproject.toml and sets UV project context
- **FZF-lua**: Fuzzy finder for files, buffers, grep, and more
- **Flash.nvim**: Enhanced motion and search with custom directional labeling
- **Mini.ai**: Advanced text objects for Python functions, classes, and statements
- **Mini.surround**: Surround text objects with brackets, quotes, etc.
- **Mini.operators**: Text manipulation operators
- **Mini.indentscope**: Visual indent scope indication
- **Spaceless.nvim**: Automatic whitespace management

### Configuration Structure
```
init.lua                    # Bootstrap and plugin loading
lua/config/
  ├── keybindings.lua      # Global LSP and keybinding setup
  ├── python.lua           # Python-specific settings and keybindings
  └── markdown.lua         # Markdown file type settings
lua/plugins/
  ├── init.lua             # Core plugin (mini.operators)
  ├── completion.lua       # nvim-cmp with LSP, snippets, buffer, and path sources
  ├── mason.lua            # Mason LSP server and tool management
  ├── python-lsp.lua       # LSP configurations (BasedPyright + Ruff)
  ├── python-dap.lua       # Debug adapter configuration (nvim-dap + debugpy)
  ├── uv-integration.lua   # UV package manager integration
  ├── markdown.lua         # Markdown plugins (render-markdown, preview, table-mode)
  ├── treesitter.lua       # TreeSitter with textobjects support
  ├── editing.lua          # Text editing plugins (mini.ai, mini.surround, spaceless)
  ├── navigation.lua       # Navigation plugins (flash.nvim + fzf-lua)
  └── ui.lua               # UI plugins (which-key, mini.indentscope)
```

## Python Development Workflow

### Key Bindings (Space as leader)
- `<leader>p*`: Python commands (run, test, interactive)
- `<leader>x*`: UV package management
- `<leader>d*`: Debugging commands
- `<leader>l*`: LSP actions
- `<leader>f*`: Find/search commands (FZF-lua)
- `<leader>m*`: Markdown commands
- `<leader>c*`: Compile commands
- `<leader>t*`: Table commands

### LSP Configuration
- **BasedPyright**: Primary language server for type checking
- **Ruff**: Linting and formatting (hover disabled in favor of BasedPyright)
- Both configured to work with virtual environments
- Auto-format on save available via `<leader>lf`
- **Diagnostic Display**: Uses floating windows instead of above-line virtual text for better readability

### Debugging Setup
- Debugpy adapter configured with Mason-installed debugpy at `~/.local/share/nvim/mason/packages/debugpy/venv/bin/python`
- UI automatically opens/closes with debug sessions
- Virtual text shows variable values during debugging
- F-keys mapped for step debugging (F5=continue, F10=step_over, F11=step_into, F12=step_out)

## Navigation and Search

### FZF-lua Integration
- Fuzzy finder with preview support
- Custom keybindings for files, buffers, grep, and history
- Configurable window size and positioning (85% height, 80% width)
- LSP symbol search support for documents and workspace

### Flash.nvim Motion
- Enhanced f/F/t/T motions with custom directional labeling
- Labels ahead of cursor: `dsrn`
- Labels behind cursor: `oaei`
- Treesitter integration with `?` key
- Search integration with `/` and `?` commands

### Text Objects (Mini.ai)
- Python-specific: `af`/`if` (function), `ac`/`ic` (class), `as`/`is` (statement)
- Enhanced bracket handling: `a(`/`i(`, `a[`/`i[`, `a{`/`i{`
- String objects: `a"`/`i"`, `a'`/`i'`, `a``/`i``
- Function arguments: `aa`/`ia`
- Next/last variants: `an`/`in`, `al`/`il`
- Navigation: `g[`/`g]` to move to text object edges

## Important Notes

- Leader key: Space (`" "`)
- Local leader: Backslash (`"\"`)
- Python files use 4-space indentation, 88-character line width
- LSP servers restart automatically when changing project directories
- Configuration assumes ruff.toml exists in home directory (`~/ruff.toml`)
- Line numbers and sign column always visible
- Smart case search enabled
- Clear search highlighting with `<Esc>`
- Diagnostic display uses floating windows on CursorHold (500ms delay)
- Very magic regex mode enabled by default

## Project-Specific Features

- **Directory Change Detection**: Automatically restarts LSP and updates UV project context when changing directories
- **pyproject.toml Detection**: Sets UV project context when pyproject.toml is found in current directory
- **Mason Integration**: All LSP servers and tools managed through Mason for consistent installation paths