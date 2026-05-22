-- ~/Code/dotfiles/dot_config/mocha-neon/palette.lua
-- Mocha Neon palette — Catppuccin Mocha with 11 bumped neon accents.
-- Source of truth. Importable from Lua (sketchybar, nvim, hammerspoon, etc.).
return {
  -- Surfaces (Catppuccin Mocha originals)
  crust    = "#11111B",
  mantle   = "#181825",
  base     = "#1E1E2E",   -- main bg
  surface0 = "#313244",
  surface1 = "#45475A",
  surface2 = "#585B70",
  overlay0 = "#6C7086",
  overlay1 = "#7F849C",
  overlay2 = "#9399B2",

  -- Text (text bumped to brighter lavender-white)
  text     = "#F0F0FF",   -- BUMPED from #CDD6F4
  subtext0 = "#A6ADC8",
  subtext1 = "#BAC2DE",

  -- Bumped accents (11 of them)
  mauve    = "#B347FF",   -- BUMPED from #CBA6F7 — primary accent
  lavender = "#9580FF",   -- BUMPED from #B4BEFE
  pink     = "#FF80BF",   -- BUMPED from #F5C2E7 — secondary accent
  red      = "#FF6B9D",   -- BUMPED from #F38BA8 — error / waiting urgent
  maroon   = "#FF6B9D",   -- merged with red
  peach    = "#FF8C42",   -- BUMPED from #FAB387 — compaction
  yellow   = "#FFD700",   -- BUMPED from #F9E2AF — gold / warning
  green    = "#50FA7B",   -- BUMPED from #A6E3A1 — success / mint
  sky      = "#8BE9FD",   -- BUMPED from #89DCEB — info / cyan
  blue     = "#8AB4F8",   -- minor bump from #89B4FA

  -- Unchanged Mocha tokens
  teal       = "#94E2D5",
  sapphire   = "#74C7EC",
  rosewater  = "#F5E0DC",
  flamingo   = "#F2CDCD",
}
