-- Python-specific configuration and keybindings

-- Auto-detect virtual environments
vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    -- Reload LSP servers when changing projects
    vim.cmd("LspRestart")
    
    -- Update UV project context
    if vim.fn.filereadable("pyproject.toml") == 1 then
      vim.g.current_uv_project = vim.fn.getcwd()
    end
  end,
})

-- Python-specific keybindings grouped by functionality
local function setup_python_keymaps()
  local wk = require("which-key")
  
  wk.add({
    { "<leader>p", group = "Python" },
    { "<leader>pr", "<cmd>!python %<cr>", desc = "Run Python File" },
    { "<leader>pi", "<cmd>!python -i %<cr>", desc = "Interactive Python" },
    { "<leader>pt", "<cmd>!python -m pytest<cr>", desc = "Run Tests" },
    { "<leader>pf", "<cmd>!python -m pytest %<cr>", desc = "Test Current File" },
    
    -- UV package management
    { "<leader>x", group = "UV" },
    { "<leader>xa", "<cmd>UVAdd<cr>", desc = "Add Package" },
    { "<leader>xd", "<cmd>UVRemove<cr>", desc = "Remove Package" },
    { "<leader>xr", "<cmd>UVRun<cr>", desc = "UV Run" },
    { "<leader>xi", "<cmd>UVInit<cr>", desc = "Init Project" },
    { "<leader>xs", "<cmd>UVSync<cr>", desc = "Sync Dependencies" },
    { "<leader>xv", "<cmd>UVStatus<cr>", desc = "UV Status" },
    
    -- FZF-Lua fuzzy finding
    { "<leader>f", group = "Find" },
    { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find Files" },
    { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Live Grep" },
    { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Find Buffers" },
    { "<leader>fh", "<cmd>FzfLua oldfiles<cr>", desc = "Recent Files" },
    { "<leader>fc", "<cmd>FzfLua grep_cword<cr>", desc = "Find Word Under Cursor" },
    { "<leader>fC", "<cmd>FzfLua grep_cWORD<cr>", desc = "Find WORD Under Cursor" },
    { "<leader>fr", "<cmd>FzfLua resume<cr>", desc = "Resume Last Search" },
    { "<leader>f:", "<cmd>FzfLua command_history<cr>", desc = "Command History" },
    { "<leader>f/", "<cmd>FzfLua search_history<cr>", desc = "Search History" },
    { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<cr>", desc = "Document Symbols" },
    { "<leader>fS", "<cmd>FzfLua lsp_workspace_symbols<cr>", desc = "Workspace Symbols" },
    
    -- Debugging
    { "<leader>d", group = "Debug" },
    { "<leader>db", desc = "Toggle Breakpoint" },
    { "<leader>dB", desc = "Conditional Breakpoint" },
    { "<leader>dr", desc = "Debug REPL" },
    { "<leader>dl", desc = "Run Last" },
    { "<leader>du", desc = "Toggle Debug UI" },
    { "<leader>de", desc = "Eval Expression" },
    
    -- LSP actions
    { "<leader>l", group = "LSP" },
    { "<leader>li", "<cmd>LspInfo<cr>", desc = "LSP Info" },
    { "<leader>lr", "<cmd>LspRestart<cr>", desc = "Restart LSP" },
    { "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, desc = "Format" },
  })
end

-- Setup keymaps when which-key is available
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(event)
    if event.data == "which-key.nvim" then
      setup_python_keymaps()
    end
  end,
})

-- Python file settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
    vim.opt_local.textwidth = 88
    vim.opt_local.colorcolumn = "89"
  end,
})