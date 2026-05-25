local M = {}

local state_file = vim.fn.stdpath("state") .. "/lazy-weekly-check.txt"

local function is_monday()
  return tonumber(os.date("%w")) == 1
end

local function checked_this_monday(key)
  local ok, lines = pcall(vim.fn.readfile, state_file)
  return ok and lines[1] == key
end

local function mark_checked(key)
  vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
  vim.fn.writefile({ key }, state_file)
end

local function report_pending_updates(runner)
  runner:wait(function()
    local ok, checker = pcall(require, "lazy.manage.checker")
    if ok then
      checker.report(true)
    end
  end)
end

local function run_monday_check()
  if #vim.api.nvim_list_uis() == 0 or not is_monday() then
    return
  end

  local key = os.date("%Y-%m-%d")
  if checked_this_monday(key) then
    return
  end

  mark_checked(key)

  local ok, lazy = pcall(require, "lazy")
  if ok then
    report_pending_updates(lazy.check({ show = false }))
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("LazyMondayCheck", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      -- Lazy only supports interval-based checks; keep prompts to Monday openings.
      vim.defer_fn(run_monday_check, 1000)
    end,
  })
end

return M
