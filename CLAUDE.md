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
  ├── python.lua           # Python-specific settings and keybindings
  └── markdown.lua         # Markdown file type settings
lua/plugins/
  ├── init.lua             # Core plugins (which-key, mini.operators, mini.indentscope, spaceless)
  ├── completion.lua       # nvim-cmp configuration
  ├── mason.lua            # LSP server management
  ├── python-lsp.lua       # LSP configurations (BasedPyright + Ruff)
  ├── python-dap.lua       # Debug adapter configuration
  ├── uv-integration.lua   # UV package manager integration
  ├── markdown.lua         # Markdown plugins and preview
  ├── treesitter.lua       # TreeSitter configuration
  ├── fzf-lua.lua          # FZF fuzzy finder
  ├── flash.lua            # Enhanced motion and search
  └── mini-ai.lua          # Text objects and surround operations
```

## Python Development Workflow

### Key Bindings (Space as leader)
- `<leader>p*`: Python commands (run, test, interactive)
- `<leader>x*`: UV package management
- `<leader>d*`: Debugging commands
- `<leader>l*`: LSP actions

### LSP Configuration
- **BasedPyright**: Primary language server for type checking
- **Ruff**: Linting and formatting (hover disabled in favor of BasedPyright)
- Both configured to work with virtual environments
- Auto-format on save available via `<leader>lf`
- **Diagnostic Display**: Uses floating windows instead of above-line virtual text for better readability

### Debugging Setup
- Debugpy adapter configured with Mason-installed debugpy
- UI automatically opens/closes with debug sessions
- Virtual text shows variable values during debugging
- F-keys mapped for step debugging

## Navigation and Search

### FZF-lua Integration
- Fuzzy finder with preview support
- Custom keybindings for files, buffers, grep, and history
- Configurable window size and positioning

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