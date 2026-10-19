-- <leader>m toggles checkboxes (`- [ ]` <-> `- [x]`) on the current line, or
-- on every line of a visual selection. <leader>x is Trouble, <leader>t is Neotest.
-- An ftplugin, not a FileType autocmd in config/autocmds.lua: that file loads on
-- VeryLazy, after the FileType of a file opened from the command line has fired.
local function toggle_checkboxes(first, last)
  for lnum = first, last do
    local line = vim.fn.getline(lnum)
    local new = line:gsub("^(%s*[-*+] )%[ %]", "%1[x]", 1)
    if new == line then
      new = line:gsub("^(%s*[-*+] )%[[xX]%]", "%1[ ]", 1)
    end
    if new ~= line then
      vim.fn.setline(lnum, new)
    end
  end
end

vim.keymap.set("n", "<leader>m", function()
  local lnum = vim.fn.line(".")
  toggle_checkboxes(lnum, lnum)
end, { buffer = true, desc = "Toggle checkbox" })

vim.keymap.set("x", "<leader>m", function()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  toggle_checkboxes(math.min(a, b), math.max(a, b))
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
end, { buffer = true, desc = "Toggle checkboxes" })
