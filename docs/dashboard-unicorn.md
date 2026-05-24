# Dashboard unicorn — Mocha Neon animated header

Snacks.nvim dashboard header that renders a heraldic unicorn with animated
highlights. Lives at `dot_config/nvim/lua/plugins/dashboard.lua`.

## What it is

- **Art source**: openclipart.org/detail/338103 (medieval heraldic unicorn
  silhouette, CC0). Rendered to 32×16 braille via `chafa` with
  `-f symbols --symbols=braille --bg=white --fg=black --size=32x16`.
- **Animation layers**:
  1. Whole-body color cycle through every Mocha Neon accent (mauve → pink →
     lavender → cyan → green → gold → orange → red, looped). Smooth lerp
     between adjacent stops. ~10s full cycle, 12 ticks × 8 stops × 100ms.
  2. Speed-trail at the back hooves — last 6–8 cols of `body_lines[14]` and
     `body_lines[15]` carry trail characters (`⣀⣄⠆⠂` + `⣶⣦⠆⠁`). Color
     flickers red → orange → gold every 200ms (discrete frame rotation).
  3. Horn (top line) stays static gold for contrast.

## File anatomy

```
horn  ─────────────────────────────  static gold, 1 row
body_lines[1..13]  ─────────────────  body cycle, plain sections
body_lines[14] (split: prefix + trail)  back-hoof line + fire trail right edge
body_lines[15] (split: prefix + trail)  bottom-hoof line + fire trail right edge
↓
{ section = "keys", … }
{ section = "recent_files", limit = 3 }
{ section = "startup" }
```

Each unicorn line is its own snacks section with `padding = 0` so they stack
into one contiguous figure. Lines that carry animated regions are split into
`{prefix, hl=body}` + `{trail, hl=flame}` chunks. Snacks `text` arrays do
**not** support literal `"\n"` entries — every line *must* be its own
section, or you get `attempt to index a nil value` from `dashboard.lua:382`.

## Tuning knobs

| Knob | Where | Effect |
|---|---|---|
| `seg_ticks` | top of body-color block | bigger = slower cycle (each segment = `seg_ticks × 100ms`) |
| `palette.cycle` | palette table | reorder / add / remove color stops |
| `palette.flame` | palette table | trail flicker colors (3 stops, 200ms each) |
| timer interval `100` | `start_timer(100, …)` for body | smaller = smoother but heavier |
| trail chars `b14_trail` / `b15_trail` | next to body_lines splits | edit to change trail look / length |

## Sizing

- 32×16 is the locked size (fits a 1440-ish vertical terminal with the keys
  + recent_files + startup sections still visible).
- To shrink: re-render with `chafa --size=28×14` (middle) or `24×12` (small)
  using `/tmp/unicorn-art/heraldic.png` (the CC0 source PNG; re-download from
  openclipart 338103 if missing).
- Going larger than 32×16 pushes menu items off-screen — verified in earlier
  iteration.

## Tried but reverted

- **Eye highlight** (one-pixel braille char on the head pulsing gold/pink) —
  could not nail a satisfying position on the 32×16 silhouette across three
  attempts (`body_lines[3]` col 11, `body_lines[1]` col 13, `body_lines[5]`
  col 12). Whole-body cycle covers the same "alive" signal without the
  positional fragility.
- **Upward flames at hooves** — first pass put `⡆⡏⡆` flame columns under
  the hooves like bonfires. User preferred a Back-to-the-Future tire trail
  going **right**, so the design moved into the right edge of the existing
  hoof lines (no extra rows below the unicorn).

## Reload note

The animation timers are stored on `_G.__SnacksDashUnicornTimers`. On
`:Lazy reload` or restarting the plugin opts function, the existing timers
are stopped + closed before new ones start, so handles don't leak.
