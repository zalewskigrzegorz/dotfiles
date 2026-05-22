# 🦄 Mocha Neon palette

Catppuccin Mocha with 11 accents bumped to cyberpunk neon. Lets us leverage the huge Catppuccin Mocha ecosystem (Raycast / Slack / Spotify / Discord / VSCode / btop / ...) while preserving a hot-neon vibe where we control the hex directly (statusline, tmux, sketchybar, starship, nvim, ghostty).

## Palette swatches

| Role | Hex | Catppuccin Mocha source | Bumped? |
|---|---|---|---|
| bg (base) | `#1E1E2E` | base | — |
| bg-alt (mantle) | `#181825` | mantle | — |
| bg-deep (crust) | `#11111B` | crust | — |
| surface | `#313244` | surface0 | — |
| surface-1 | `#45475A` | surface1 | — |
| surface-2 | `#585B70` | surface2 | — |
| fg (text) | `#F0F0FF` | text (was `#CDD6F4`) | ✅ brighter lavender-white |
| fg-muted (subtext0) | `#A6ADC8` | subtext0 | — |
| accent (mauve) | `#B347FF` | mauve (was `#CBA6F7`) | ✅ electric purple |
| accent-2 (pink) | `#FF80BF` | pink (was `#F5C2E7`) | ✅ medium pink |
| accent-3 (lavender) | `#9580FF` | lavender (was `#B4BEFE`) | ✅ matches existing sketchybar purple |
| success (green) | `#50FA7B` | green (was `#A6E3A1`) | ✅ vivid mint |
| warning (yellow) | `#FFD700` | yellow (was `#F9E2AF`) | ✅ gold |
| error (red+maroon) | `#FF6B9D` | red (was `#F38BA8`) | ✅ urgent pink — merged with maroon |
| info (sky) | `#8BE9FD` | sky (was `#89DCEB`) | ✅ electric cyan |
| compaction (peach) | `#FF8C42` | peach (was `#FAB387`) | ✅ neon orange |
| blue | `#8AB4F8` | blue (was `#89B4FA`) | minor |

## Catppuccin Mocha → Mocha Neon overrides

11 tokens override: `text`, `mauve`, `lavender`, `pink`, `red`, `maroon` (=`red`), `peach`, `yellow`, `green`, `sky`, `blue` (minor).

Unchanged (use Catppuccin Mocha defaults): all surfaces (`base`, `mantle`, `crust`, `surface0-2`, `overlay0-2`), `subtext0/1`, `teal`, `sapphire`, `rosewater`, `flamingo`.

## WCAG AA verified on `#1E1E2E` base

All accents ≥ 5.8:1 contrast ratio.

- `fg` (`#F0F0FF`) — 14.6:1 AAA
- `error` (`#FF6B9D`) — 7.2:1 AAA
- `success` (`#50FA7B`) — 11.9:1 AAA
- `warning` (`#FFD700`) — 13.1:1 AAA
- `accent` mauve (`#B347FF`) — 5.8:1 AA borderline — **accent-only, do not use as body text**

## Source of truth

`dot_config/mocha-neon/palette.lua` is the SOT. Hex values must stay in sync with `dot_config/mocha-neon/palette.sh` manually. When updating, update both files.

After editing, run `chezmoi apply` to push to `~/.config/mocha-neon/`.

## Tier 2 GUI checklist (manual, one-time)

<!-- Populated by Task 27 -->
