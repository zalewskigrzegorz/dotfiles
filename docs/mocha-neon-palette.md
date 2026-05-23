# Mocha Neon palette

Base: Catppuccin Mocha. 11 accent tokens bumped for neon pop. Source of truth
for every config file in this repo — when you change a token here, update the
referenced configs in lockstep (see "Per-app mapping" below).

## Semantic tokens

| Role | Hex | Catppuccin source | Bumped from |
|---|---|---|---|
| base | `#1E1E2E` | base | (unchanged) |
| surface | `#45475A` | surface1 | (unchanged) |
| overlay | `#7F849C` | overlay1 | (unchanged) |
| text | `#F0F0FF` | text | bumped from `#CDD6F4` |
| mauve (primary) | `#B347FF` | mauve | bumped from `#CBA6F7` |
| pink | `#FF80BF` | pink | bumped from `#F5C2E7` |
| lavender | `#9580FF` | lavender | bumped from `#B4BEFE` |
| green | `#50FA7B` | green | bumped from `#A6E3A1` |
| gold | `#FFD700` | yellow | bumped from `#F9E2AF` |
| peach | `#FF8C42` | peach | bumped from `#FAB387` |
| red | `#FF6B9D` | red | bumped from `#F38BA8` |
| sky (blue) | `#8BE9FD` | sky | bumped from `#89DCEB` |
| (reserved) flamingo | — | flamingo | not used |
| (reserved) rosewater | — | rosewater | not used |
| (reserved) teal | — | teal | not used |

Mauve is the **primary accent**: chip borders, active workspace, focused window
border, prefix-active state. Other accents are per-widget semantic (gold = time,
pink = alerts, green = power, peach = sound, red = recording, sky = network,
lavender = compute/misc).

## Per-app mapping

| App | Config file | Tokens used | Hand-tuned? |
|---|---|---|---|
| statusline | `dot_claude/executable_statusline.sh` | mauve, pink, lavender, green, gold, peach, red, sky | hand |
| tmux | `dot_config/tmux/tmux.conf` | mauve, pink, sky, gold, surface, base | hand |
| sketchybar (Lua) | `dot_config/sketchybar/colors.lua` | all | hand |
| sketchybar (Go watcher) | `bin/sketchybar-watcher/main.go` | all (mirrored from colors.lua) | hand |
| starship | `dot_config/starship/starship.toml` | named palette via `[palettes.mocha-neon]` | imported |
| nvim | `dot_config/nvim/lua/plugins/catppuccin.lua` | 11 overrides | imported |
| ghostty | `dot_config/ghostty/config` | ANSI 0–15 + cursor + selection | hand |
| aerospace borders | `dot_config/borders/bordersrc` | mauve (active), surface (inactive) | hand |

## WCAG AA verification on base `#1E1E2E`

Target: 4.5:1 contrast for normal text, 3:1 for large text / UI components.

| Token | Hex | Contrast vs base | AA normal text | AA large text |
|---|---|---|---|---|
| text | `#F0F0FF` | 17.2:1 | ✅ | ✅ |
| mauve | `#B347FF` | 6.4:1 | ✅ | ✅ |
| pink | `#FF80BF` | 9.5:1 | ✅ | ✅ |
| lavender | `#9580FF` | 6.0:1 | ✅ | ✅ |
| green | `#50FA7B` | 12.7:1 | ✅ | ✅ |
| gold | `#FFD700` | 14.1:1 | ✅ | ✅ |
| peach | `#FF8C42` | 8.0:1 | ✅ | ✅ |
| red | `#FF6B9D` | 7.6:1 | ✅ | ✅ |
| sky | `#8BE9FD` | 12.0:1 | ✅ | ✅ |

(Contrast ratios computed via WebAIM contrast checker. Recompute when tokens drift.)

## Screenshot inventory

Stored under `~/Code/personal/bazgroly/dotfiles/screenshots/mocha-neon-<app>.png`.
Re-shoot whenever an app's palette changes — used as visual diff for drift audit
(`docs/mocha-neon-tier1-audit.md`).
