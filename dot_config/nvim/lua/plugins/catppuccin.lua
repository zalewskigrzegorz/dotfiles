-- Mocha Neon — Catppuccin Mocha with 11 bumped accents to match the
-- terminal stack (statusline / tmux / sketchybar / starship).
return {
  "catppuccin/nvim",
  name = "catppuccin",
  priority = 1000,
  lazy = false,
  config = function()
    require("catppuccin").setup({
      flavour = "mocha",
      color_overrides = {
        mocha = {
          text     = "#F0F0FF",
          mauve    = "#B347FF",
          lavender = "#9580FF",
          pink     = "#FF80BF",
          red      = "#FF6B9D",
          maroon   = "#FF6B9D",
          peach    = "#FF8C42",
          yellow   = "#FFD700",
          green    = "#50FA7B",
          sky      = "#8BE9FD",
          blue     = "#8AB4F8",
        },
      },
      transparent_background = false,
      term_colors = true,
      dim_inactive = { enabled = false },
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        notify = true,
        mini = { enabled = true, indentscope_color = "" },
        which_key = true,
        telescope = { enabled = true },
        mason = true,
        markdown = true,
        flash = true,
        indent_blankline = { enabled = true },
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
