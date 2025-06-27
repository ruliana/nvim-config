# Mini.ai Installation Guide for AI Agents

This guide provides step-by-step instructions for installing and configuring mini.ai in Neovim with TreeSitter support. Follow this exact sequence to avoid common dependency issues.

## Prerequisites

Before beginning, ensure you have:
- Neovim 0.8+ installed
- Lazy.nvim plugin manager configured
- Basic understanding of Lua configuration files

## Critical Dependencies

⚠️ **IMPORTANT**: Mini.ai requires TreeSitter textobjects queries to function properly. Missing this dependency causes errors like:
```
E5108: Error executing lua (mini.ai) Can not get query for buffer 1 and language "python"
```

## Installation Steps

### Step 1: Install TreeSitter with Textobjects Support

**Create or update** `lua/plugins/treesitter.lua`:

```lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",  -- CRITICAL: Required for mini.ai
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { 
          "markdown", 
          "markdown_inline", 
          "html", 
          "python", 
          "lua",
          "bash",
          "json",
          "yaml",
        },
        highlight = { enable = true },
        indent = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<C-space>",
            node_incremental = "<C-space>",
            scope_incremental = "<C-s>",
            node_decremental = "<M-space>",
          },
        },
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ["af"] = "@function.outer",
              ["if"] = "@function.inner",
              ["ac"] = "@class.outer",
              ["ic"] = "@class.inner",
            },
          },
        },
      })
    end,
  },
}
```

**Key Points:**
- `nvim-treesitter-textobjects` dependency is MANDATORY
- Include languages you plan to use with mini.ai in `ensure_installed`
- The `textobjects.select` configuration provides fallback text objects

### Step 2: Install Mini.ai Plugin

**Create** `lua/plugins/mini-ai.lua`:

```lua
return {
  {
    "echasnovski/mini.ai",
    version = false,
    event = "VeryLazy",
    config = function()
      local ai = require("mini.ai")
      
      ai.setup({
        custom_textobjects = {
          -- TreeSitter-based text objects for Python
          f = ai.gen_spec.treesitter({
            a = "@function.outer",
            i = "@function.inner",
          }, {}),
          c = ai.gen_spec.treesitter({
            a = "@class.outer", 
            i = "@class.inner",
          }, {}),
          s = ai.gen_spec.treesitter({
            a = "@statement.outer",
            i = "@statement.inner", 
          }, {}),
          -- Enhanced bracket handling
          ['('] = { '%b()', '^.().*().$' },
          ['['] = { '%b[]', '^.().*().$' },
          ['{'] = { '%b{}', '^.().*().$' },
          -- String and quote handling
          ['"'] = { '"%b""', '^.().*().$' },
          ["'"] = { "'%b''", "^.().*().$" },
          ['`'] = { '`%b``', '^.().*().$' },
          -- Function arguments  
          a = ai.gen_spec.argument({ brackets = { '%b()', '%b[]', '%b{}' } }),
        },
        
        mappings = {
          around = 'a',
          inside = 'i',
          around_next = 'an',
          inside_next = 'in',
          around_last = 'al',
          inside_last = 'il',
          goto_left = 'g[',
          goto_right = 'g]',
        },

        n_lines = 500,
        search_method = 'cover_or_next',
        silent = false,
      })
    end,
  },
}
```

### Step 3: Install Plugins

Run the installation command:

```bash
nvim --headless -c "Lazy! sync" -c "qa"
```

**Expected behavior**: You should see TreeSitter textobjects plugin being cloned and installed.

### Step 4: Verify Installation

#### 4.1 Check TreeSitter Parsers
```bash
nvim --headless -c "lua local installed = require('nvim-treesitter.info').installed_parsers(); for _, lang in ipairs(installed) do if lang == 'python' then print('✅ Python parser installed') end end" -c "qa"
```

**Expected output**: `✅ Python parser installed`

#### 4.2 Verify Textobjects Queries
```bash
nvim --headless -c "lua local query = require('nvim-treesitter.query'); print('Textobjects available:', query.has_query_files('python', 'textobjects'))" -c "qa"
```

**Expected output**: `Textobjects available: true`

#### 4.3 Test Mini.ai Functionality
Create a test file:
```bash
echo -e "class TestClass:\n    def test_method(self):\n        return 'hello'" > /tmp/test_mini_ai.py
```

Test mini.ai:
```bash
nvim --headless /tmp/test_mini_ai.py -c "lua local ok, err = pcall(function() require('mini.ai').select_textobject('i', 'c') end); print('Mini.ai test:', ok and 'SUCCESS ✅' or 'FAILED ❌: ' .. tostring(err))" -c "qa"
```

**Expected output**: `Mini.ai test: SUCCESS ✅`

Clean up:
```bash
rm /tmp/test_mini_ai.py
```

## Configuration Organization

### File Structure
Your plugin directory should look like:
```
lua/plugins/
├── treesitter.lua      # TreeSitter configuration
├── mini-ai.lua         # Mini.ai configuration
├── completion.lua      # Other plugins...
└── ...
```

### ⚠️ Common Mistakes to Avoid

1. **DO NOT** put TreeSitter config in `markdown.lua` or other unrelated files
2. **DO NOT** forget the `nvim-treesitter-textobjects` dependency
3. **DO NOT** skip the verification steps
4. **DO NOT** use mini.ai before TreeSitter parsers are installed

## Troubleshooting

### Error: "Can not get query for buffer X and language 'python'"

**Cause**: Missing TreeSitter textobjects plugin or queries

**Solution**:
1. Verify `nvim-treesitter-textobjects` is in dependencies
2. Check textobjects queries: `lua print(require('nvim-treesitter.query').has_query_files('python', 'textobjects'))`
3. If false, reinstall with: `nvim --headless -c "Lazy! sync" -c "qa"`

### Error: "attempt to call field 'gen_spec' (a nil value)"

**Cause**: Mini.ai not properly loaded

**Solution**:
1. Ensure mini.ai is installed: `nvim --headless -c "lua print(pcall(require, 'mini.ai'))" -c "qa"`
2. Check for syntax errors in configuration
3. Restart Neovim completely

### TreeSitter Parser Not Found

**Solution**:
1. Add language to `ensure_installed` in treesitter.lua
2. Run: `nvim --headless -c "lua require('nvim-treesitter.install').update({ with_sync = true })" -c "qa"`
3. Verify: `nvim --headless -c "lua print('Installed:', table.concat(require('nvim-treesitter.info').installed_parsers(), ', '))" -c "qa"`

## Usage Examples

After successful installation, you can use these text objects:

### Basic Usage
- `vic` - select inside class
- `vac` - select around class  
- `vif` - select inside function
- `vaf` - select around function
- `vis` - select inside statement
- `vas` - select around statement

### Advanced Usage
- `dac` - delete around class
- `yif` - yank inside function
- `cic` - change inside class
- `van` - select around next text object
- `g[` - jump to start of text object
- `g]` - jump to end of text object

### Arguments and Brackets
- `via` - select inside arguments
- `va(` - select around parentheses
- `vi"` - select inside quotes

## Final Verification Checklist

Before considering installation complete, verify:

- [ ] TreeSitter plugin installed with textobjects dependency
- [ ] Python (or target language) parser installed
- [ ] Textobjects queries available for target language
- [ ] Mini.ai loads without errors
- [ ] Text object selection works in practice (`vic`, `vif`, etc.)
- [ ] No error messages when using mini.ai commands

## Success Indicators

✅ **Installation successful when**:
- No errors during plugin sync
- `vic` selects inside Python classes
- `vif` selects inside Python functions  
- TreeSitter highlighting works
- Text object selection is responsive

This guide ensures reliable mini.ai installation by addressing the most common dependency issues and providing comprehensive verification steps.