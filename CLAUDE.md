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

### Language Support Architecture
- **LSP Stack**: BasedPyright (type checking) + Ruff (linting/formatting)
- **Debugging**: nvim-dap with Python adapter and UI
- **Completion**: nvim-cmp with LSP, snippets, buffer, and path sources
- **UV Integration**: Built-in support for UV package management

### Key Integrations
- **UV Package Manager**: Native commands for Python project management
- **Auto-detection**: Automatically restarts LSP when changing directories
- **Virtual Environment**: Detects pyproject.toml and sets UV project context

### Configuration Structure
```
init.lua                    # Bootstrap and plugin loading
lua/config/
  ├── python.lua           # Python-specific settings and keybindings
  └── markdown.lua         # Markdown file type settings
lua/plugins/
  ├── init.lua             # Core plugins (which-key)
  ├── completion.lua       # nvim-cmp configuration
  ├── mason.lua            # LSP server management
  ├── python-lsp.lua       # LSP configurations (BasedPyright + Ruff)
  ├── python-dap.lua       # Debug adapter configuration
  ├── uv-integration.lua   # UV package manager integration
  └── markdown.lua         # Markdown plugins and preview
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

### Debugging Setup
- Debugpy adapter configured with Mason-installed debugpy
- UI automatically opens/closes with debug sessions
- Virtual text shows variable values during debugging
- F-keys mapped for step debugging

## Important Notes

- Leader key: Space (`" "`)
- Local leader: Backslash (`"\"`)
- Python files use 4-space indentation, 88-character line width
- LSP servers restart automatically when changing project directories
- Configuration assumes ruff.toml exists in home directory (`~/ruff.toml`)