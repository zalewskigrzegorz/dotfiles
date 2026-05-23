# Mocha Neon — Tier 1 color drift audit

Walk each Tier 1 app and verify the **bumped** Mocha Neon palette is in effect.
Programmatic pre-check ran 2026-05-23 (greps the config for bumped hex
markers: `B347FF`, `FF80BF`, `FFD700`, `FF8C42`, `8BE9FD`, `FF6B9D`, `50FA7B`,
`9580FF`, `F0F0FF`, `1E1E2E`). Visual verify still required — pre-check confirms
the config is wired but only your eyes confirm the app actually renders neon.

## Status legend

- ✅ **config-OK** — Mocha Neon hex present in the config file (pre-check passed).
- 🔍 **visual-pending** — config OK but no screenshot yet; user must do live verify.
- ⚠️ **pastel-accepted** — vanilla Catppuccin / no overrides on purpose (e.g. bat).
- ❌ **drift** — config doesn't have bumped hex; needs EDIT.

## Audit table (2026-05-23 walk)

| App | Source | Pre-check | Visual | Screenshot |
|---|---|---|---|---|
| statusline (Claude Code) | `dot_claude/executable_statusline.sh` | ✅ 9 tokens | 🔍 verified live in Claude Code (model compact + peach ctx) | `mocha-neon-statusline.png` |
| tmux | `dot_config/tmux/tmux.conf` | ✅ 7 tokens | 🔍 verified live (dynamic chips + iconified labels + waiting threshold) | `mocha-neon-tmux.png` |
| sketchybar (Lua) | `dot_config/sketchybar/colors.lua` | ✅ 10 tokens | 🔍 verified live (per-chip border colors) | `mocha-neon-sketchybar.png` |
| sketchybar (Go watcher) | `bin/sketchybar-watcher/main.go` workspaceColors + named tokens | ✅ 8 tokens | 🔍 verified (workspace icon colors all neon) | (same as above) |
| starship | `dot_config/starship/starship.toml` | ✅ 10 tokens | 🔍 verified (palette + character glyph) | `mocha-neon-starship.png` |
| nvim | `dot_config/nvim/lua/plugins/catppuccin.lua` | ✅ 9 tokens | 🔍 pending — open nvim, screenshot dashboard + diff colors | `mocha-neon-nvim.png` |
| ghostty | `dot_config/ghostty/config` | ✅ 9 tokens | 🔍 pending — open ghostty terminal palette test | `mocha-neon-ghostty.png` |
| lazygit | `dot_config/lazygit/config.yml` | ✅ 6 tokens | 🔍 pending — `lazygit`, screenshot diff side | `mocha-neon-lazygit.png` |
| btop | `dot_config/btop/themes/mocha-neon.theme` (active via `color_theme = "mocha-neon"`) | ✅ 10 tokens (in theme file) | 🔍 pending — `btop`, screenshot graphs | `mocha-neon-btop.png` |
| bat | `dot_config/bat/config` uses `Catppuccin Mocha` built-in | ⚠️ pastel-accepted | n/a — syntax highlight, no neon needed | — |
| delta | `dot_config/delta/themes.gitconfig` | ✅ 5 tokens | 🔍 pending — `git diff` side-by-side screenshot | `mocha-neon-delta.png` |
| nushell | `dot_config/nushell/autoload/mocha-neon-colors.nu` (loaded via autoload) | ✅ 10 tokens | 🔍 verified live (vi-mode glyph + prompt) | `mocha-neon-nushell.png` |
| superfile | `dot_config/superfile/theme/mocha-neon.toml` (forked from catppuccin.toml 2026-05-23) | ✅ 9 tokens (fork) | 🔍 pending — `spf`, screenshot file panel | `mocha-neon-superfile.png` |
| television | `dot_config/television/config.toml` | ✅ 3 tokens | 🔍 pending — `tv`, screenshot picker | `mocha-neon-tv.png` |
| spotify-player | `dot_config/spotify-player/theme.toml` | ✅ 7 tokens | 🔍 pending — `spotify_player`, screenshot UI | `mocha-neon-spotify-player.png` |
| zed | `dot_config/zed/settings.json` | ✅ 7 tokens | 🔍 pending — Zed editor, screenshot syntax | `mocha-neon-zed.png` |
| borders (aerospace) | `dot_config/borders/bordersrc` | ✅ 1 token (active=mauve, inactive=surface) | 🔍 verified live (mauve focused border) | `mocha-neon-borders.png` |
| aerospace | n/a (borders own the visual) | n/a | n/a | — |

## How to do the visual walk

For each row marked `🔍 pending`:

1. Open the app on the active workspace.
2. Take a focused screenshot showing the most prominent UI surface.
3. Visually confirm at least mauve `#B347FF` OR pink `#FF80BF` is present.
4. If the screenshot reads "pastel" (no neon pop), mark status `❌ drift` and
   open a follow-up EDIT against the listed config file.

Screenshots: `~/Code/personal/bazgroly/dotfiles/screenshots/`

## Last walked

- **2026-05-23 — programmatic pre-check + partial live verify.** All 17
  source configs (excluding bat which is intentionally vanilla) confirmed to
  contain bumped Mocha Neon hex. Live-verified: statusline, tmux, sketchybar,
  starship, nushell, borders. Remaining `🔍 pending` apps need user screenshot pass.
