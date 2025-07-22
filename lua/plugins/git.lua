return {
  {
    "f-person/git-blame.nvim",
    event = "VeryLazy",
    config = function()
      require("gitblame").setup({
        enabled = true,
        message_template = " <summary> • <date> • <author>",
        date_format = "%m/%d/%y %H:%M:%S",
        virtual_text_column = 1,
      })
      
      -- Git Blame keybindings
      vim.keymap.set("n", "<leader>gb", "<cmd>GitBlameToggle<CR>", { 
        desc = "Toggle Git Blame",
        silent = true 
      })
      vim.keymap.set({"n", "v"}, "<leader>gc", "<cmd>GitBlameCopyFileURL<CR>", { 
        desc = "Copy File URL",
        silent = true 
      })
      vim.keymap.set("n", "<leader>go", "<cmd>GitBlameOpenFileURL<CR>", { 
        desc = "Open File URL",
        silent = true 
      })
      vim.keymap.set("n", "<leader>gC", "<cmd>GitBlameCopyCommitURL<CR>", { 
        desc = "Copy Commit URL", 
        silent = true 
      })
      vim.keymap.set("n", "<leader>gO", "<cmd>GitBlameOpenCommitURL<CR>", { 
        desc = "Open Commit URL",
        silent = true 
      })
    end,
  },
  {
    "emmanueltouzery/agitator.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    config = function()
      local agitator = require("agitator")
      
      -- Git time travel keybinding
      vim.keymap.set("n", "<leader>gt", function()
        agitator.git_time_machine()
      end, { 
        desc = "Git Time Travel",
        silent = true 
      })
      
      -- Git find file keybinding
      vim.keymap.set("n", "<leader>gf", function()
        agitator.open_file_git_branch()
      end, { 
        desc = "Git Find File",
        silent = true 
      })
      
      -- Search in git branch keybinding
      vim.keymap.set("n", "<leader>gs", function()
        agitator.search_git_branch()
      end, { 
        desc = "Search in Git Branch",
        silent = true 
      })
    end,
  },
}