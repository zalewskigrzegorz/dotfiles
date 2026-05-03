-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = LazyVim.safe_keymap_set

-- Use jj to exit insert mode
map("i", "jj", "<Esc>", { desc = "Exit insert mode", remap = false })

-- Close window/buffer safely (only when no unsaved changes)
-- Closes window if multiple windows exist, otherwise closes buffer only if unmodified
map("n", "<leader>q", function()
  local win_count = vim.fn.winnr("$")
  local buf = vim.api.nvim_get_current_buf()
  local is_modified = vim.api.nvim_buf_get_option(buf, "modified")
  
  if win_count > 1 then
    -- Multiple windows: use :q which respects unsaved changes
    vim.cmd("q")
  else
    -- Single window: only close buffer if it's not modified
    if is_modified then
      vim.notify("Buffer has unsaved changes. Save first or use :q!", vim.log.levels.WARN)
    else
      vim.cmd("bdelete")
    end
  end
end, { desc = "Close window or unmodified buffer", remap = false })

-- Existing keymap
map("n", "<leader>ff", "<cmd>lua require'telescope.builtin'.find_files({ find_command = {'rg', '--files', '--hidden', '-g', '!.git' }})<cr>", { desc = "Find files" })