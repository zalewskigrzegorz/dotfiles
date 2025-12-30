-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = LazyVim.safe_keymap_set

-- Use jj to exit insert mode
map("i", "jj", "<Esc>", { desc = "Exit insert mode", remap = false })

-- Repurpose Escape to close window/buffer intelligently
map("n", "<Esc>", function()
  if vim.fn.winnr("$") > 1 then
    vim.cmd("q")
  else
    vim.cmd("bdelete")
  end
end, { desc = "Close window or buffer", remap = false })

-- Existing keymap
map("n", "<leader>ff", "<cmd>lua require'telescope.builtin'.find_files({ find_command = {'rg', '--files', '--hidden', '-g', '!.git' }})<cr>", { desc = "Find files" })