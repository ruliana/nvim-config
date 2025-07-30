-- Global keybindings that apply across all file types

-- LSP actions (available globally when LSP is active)
local function setup_global_keymaps()
  local wk = require("which-key")
  
  wk.add({
    -- LSP actions
    { "<leader>l", group = "LSP" },
    { "<leader>li", "<cmd>LspInfo<cr>", desc = "LSP Info" },
    { "<leader>lr", "<cmd>LspRestart<cr>", desc = "Restart LSP" },
    { "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, desc = "Format" },
    { "<leader>ll", function() vim.diagnostic.open_float() end, desc = "Show Diagnostics" },
    
    -- Search and Replace
    { "<leader>s", group = "Search" },
    { "<leader>ss", ":%s/\\v", desc = "Search/Replace (very magic)", mode = "n" },
    { "<leader>ss", ":s/\\v", desc = "Search/Replace (very magic)", mode = "v" },
  })
end

-- Setup keymaps when which-key is available
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(event)
    if event.data == "which-key.nvim" then
      setup_global_keymaps()
    end
  end,
})