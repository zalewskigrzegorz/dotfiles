-- ~/.config/nvim/lua/plugins/test.lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-jest", -- Add Jest adapter
    },
    opts = {
      adapters = {
        ["neotest-jest"] = {
          jestCommand = "pnpm jest",
          env = { CI = true },
          cwd = function()
            return vim.fn.getcwd()
          end,
        },
      },
    },
  },
}
