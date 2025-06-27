return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    priority = 100,
    config = function()
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      
      -- Custom diagnostic handler for above-line positioning
      local function setup_above_line_diagnostics()
        -- Create custom highlight group for diagnostic virtual text
        -- Slightly darker than comments for subtle appearance
        vim.api.nvim_set_hl(0, "DiagnosticVirtualTextCustom", {
          fg = "#5c6370",  -- Darker grey than typical comment color
          italic = true,
        })
        
        -- Disable default virtual text
        vim.diagnostic.config({
          virtual_text = false,
          float = {
            source = "always",
            border = "rounded",
            max_width = 80,
            max_height = 20,
            wrap = true,
          },
          signs = true,
          underline = true,
          update_in_insert = false,
          severity_sort = true,
        })
        
        -- Custom handler for above-line virtual text
        local ns = vim.api.nvim_create_namespace("above_line_diagnostics")
        
        local function show_diagnostics_above_line(bufnr)
          vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
          
          local diagnostics = vim.diagnostic.get(bufnr)
          for _, diagnostic in ipairs(diagnostics) do
            local line = diagnostic.lnum
            local message = diagnostic.message
            
            -- Get the line content to calculate indentation
            local line_content = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
            local indent = line_content:match("^%s*") or ""
            
            -- Truncate message if too long (accounting for indent)
            local max_width = 80 - #indent
            if #message > max_width then
              message = message:sub(1, max_width - 3) .. "..."
            end
            
            -- Add severity prefix
            local prefix = "●"
            if diagnostic.severity == vim.diagnostic.severity.ERROR then
              prefix = "✗"
            elseif diagnostic.severity == vim.diagnostic.severity.WARN then
              prefix = "⚠"
            elseif diagnostic.severity == vim.diagnostic.severity.INFO then
              prefix = "ℹ"
            elseif diagnostic.severity == vim.diagnostic.severity.HINT then
              prefix = "💡"
            end
            
            -- Set extmark with virtual line above, aligned with the line's indentation
            vim.api.nvim_buf_set_extmark(bufnr, ns, line, 0, {
              virt_lines = {{{indent .. prefix .. " " .. message, "DiagnosticVirtualTextCustom"}}},
              virt_lines_above = true,
            })
          end
        end
        
        -- Update diagnostics when they change
        vim.api.nvim_create_autocmd("DiagnosticChanged", {
          callback = function(args)
            show_diagnostics_above_line(args.buf)
          end,
        })
        
        -- Show diagnostics for current buffer
        local current_buf = vim.api.nvim_get_current_buf()
        show_diagnostics_above_line(current_buf)
      end
      
      -- Setup the custom diagnostic display
      setup_above_line_diagnostics()
      
      -- Configure LSP hover handler
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
        border = "rounded",
        max_width = 80,
        max_height = 20,
        wrap = true,
      })
      
      -- BasedPyright configuration
      lspconfig.basedpyright.setup({
        capabilities = capabilities,
        settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              exclude = { "**/node_modules", "**/__pycache__" },
              ignore = { "**/migrations" },
            },
          },
        },
      })

      -- Ruff LSP configuration
      lspconfig.ruff.setup({
        capabilities = capabilities,
        init_options = {
          settings = {
            logLevel = "error",
            args = {
              "--config", vim.fn.expand("~/ruff.toml")
            },
          }
        },
        on_attach = function(client, bufnr)
          -- Disable hover in favor of BasedPyright
          client.server_capabilities.hoverProvider = false
        end,
      })

      -- LSP keybindings
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
          local opts = { buffer = ev.buf, silent = true }
          
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', '<leader>f', function()
            vim.lsp.buf.format { async = true }
          end, opts)
        end,
      })
    end,
  }
}