-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Silence all validation for AI scratch notes under ~/Code/personal/bazgroly/.
-- These are plans/specs/brainstorms — markdownlint/marksman/prettier/spell
-- only add noise. Diagnostics, nvim-lint, conform autoformat, and spell are
-- all disabled per-buffer when the file path is under bazgroly.
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = vim.api.nvim_create_augroup("bazgroly_no_validation", { clear = true }),
  callback = function(args)
    local path = vim.api.nvim_buf_get_name(args.buf)
    local prefix = vim.fn.expand("~/Code/personal/bazgroly/")
    if path:sub(1, #prefix) ~= prefix then
      return
    end
    vim.diagnostic.enable(false, { bufnr = args.buf })
    vim.b[args.buf].autoformat = false
    vim.b[args.buf].lint_enabled = false
    -- spell is window-local; set on the current window (BufReadPost runs in it).
    vim.opt_local.spell = false
  end,
})

-- <leader>t toggles markdown checkboxes (`- [ ]` <-> `- [x]`) on the current
-- line, or on every line of a visual selection. <leader>x is LazyVim's Trouble group.
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

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("markdown_checkbox_toggle", { clear = true }),
  pattern = "markdown",
  callback = function(args)
    vim.keymap.set("n", "<leader>t", function()
      local lnum = vim.fn.line(".")
      toggle_checkboxes(lnum, lnum)
    end, { buffer = args.buf, desc = "Toggle checkbox" })
    vim.keymap.set("x", "<leader>t", function()
      local a, b = vim.fn.line("v"), vim.fn.line(".")
      toggle_checkboxes(math.min(a, b), math.max(a, b))
      vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    end, { buffer = args.buf, desc = "Toggle checkboxes" })
  end,
})
