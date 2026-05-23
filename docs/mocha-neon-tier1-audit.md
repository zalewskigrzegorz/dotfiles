# Mocha Neon — Tier 1 color drift audit

Walk each Tier 1 app post-bugfix-wave and verify the **bumped** Mocha Neon
palette is in effect. Capture deltas; for any "no" row, file an EDIT to fix.

| App | Bumped tokens applied? | Status | Notes / screenshot |
|---|---|---|---|
| statusline (Claude Code) | yes — `dot_claude/executable_statusline.sh` lines 26-46 | verify | `mocha-neon-statusline.png` |
| tmux | yes — `dot_config/tmux/tmux.conf` hex inline | verify | `mocha-neon-tmux.png` |
| sketchybar (Lua) | yes — `dot_config/sketchybar/colors.lua` | verify | `mocha-neon-sketchybar.png` |
| sketchybar (Go watcher) | yes — `bin/sketchybar-watcher/main.go` workspaceColors + named tokens | verify | (same screenshot as above) |
| starship | named palette `[palettes.mocha-neon]` in starship.toml | verify | `mocha-neon-starship.png` |
| nvim | overrides in `dot_config/nvim/lua/plugins/catppuccin.lua` | verify | `mocha-neon-nvim.png` |
| ghostty | ANSI palette in `dot_config/ghostty/config` | verify | `mocha-neon-ghostty.png` |
| lazygit | port + overrides | verify | `mocha-neon-lazygit.png` |
| btop | theme file | verify | `mocha-neon-btop.png` |
| bat | standard Catppuccin (no overrides) | accept pastel drift | (no neon needed for syntax highlight) |
| delta | git-delta theme | verify | `mocha-neon-delta.png` |
| nushell | `color_config` | verify | `mocha-neon-nushell.png` |
| superfile | port | verify | `mocha-neon-superfile.png` |
| television | `theme.toml` | verify | `mocha-neon-tv.png` |
| spotify-player | port | verify | `mocha-neon-spotify-player.png` |
| zed | overrides | verify | `mocha-neon-zed.png` |
| borders (aerospace) | active/inactive | verify | `mocha-neon-borders.png` |
| aerospace | n/a (borders own the visual) | n/a | — |

## How to verify a row

1. Open the app on the active workspace.
2. Take a focused screenshot showing the most prominent UI surface.
3. Visually confirm at least mauve `#B347FF` OR pink `#FF80BF` is present.
4. If the screenshot reads "pastel" (no neon pop), mark status `drift` and
   open a follow-up EDIT against the listed config file.

Screenshots: `~/Code/personal/bazgroly/dotfiles/screenshots/`

## Last walked

(populate when audit completes)
