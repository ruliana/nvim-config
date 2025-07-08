return {
  {
    "echasnovski/mini.ai",
    version = false,
    event = "VeryLazy",
    config = function()
      local ai = require("mini.ai")
      
      ai.setup({
        -- Table with textobject id as fields, textobject specification as values.
        -- Also use this to disable builtin textobjects. See |MiniAi.config|.
        custom_textobjects = {
          -- Python-specific text objects using TreeSitter
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
        
        -- Module mappings. Use `''` (empty string) to disable one.
        mappings = {
          -- Main textobject prefixes
          around = 'a',
          inside = 'i',
          
          -- Next/last variants
          around_next = 'an',
          inside_next = 'in',
          around_last = 'al',
          inside_last = 'il',
          
          -- Move cursor to corresponding edge of `a` textobject
          goto_left = 'g[',
          goto_right = 'g]',
        },

        -- Number of lines within which textobject is searched
        n_lines = 500,

        -- How to search for object (first inside current line, then inside
        -- neighborhood). One of 'cover', 'cover_or_next', 'cover_or_prev',
        -- 'cover_or_nearest', 'next', 'prev', 'nearest'.
        search_method = 'cover_or_next',

        -- Whether to disable showing non-error feedback
        silent = false,
      })
    end,
  },
  {
    "echasnovski/mini.surround",
    version = false,
    event = "VeryLazy",
    config = function()
      require("mini.surround").setup()
    end,
  },
}