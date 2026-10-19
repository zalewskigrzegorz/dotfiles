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
