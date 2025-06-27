return {
  {
    "benomahony/uv.nvim",
    ft = "python",
    opts = {
      auto_activate = true,
      auto_commands = true,
    },
    keys = {
      { "<leader>xr", "<cmd>UVRun<cr>", desc = "UV Run" },
      { "<leader>xa", "<cmd>UVAdd<cr>", desc = "UV Add Package" },
      { "<leader>xd", "<cmd>UVRemove<cr>", desc = "UV Remove Package" },
      { "<leader>xi", "<cmd>UVInit<cr>", desc = "UV Init Project" },
      { "<leader>xs", "<cmd>UVSync<cr>", desc = "UV Sync" },
      { "<leader>xv", "<cmd>UVStatus<cr>", desc = "UV Status" },
    },
  },
}