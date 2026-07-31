# Deck design system — Mocha Neon

Everything here is already implemented in `templates/deck-template.html`. This file is the catalogue, so you can pick a component without reading 300 lines of CSS.

## Palette

Hexes are copied from `~/.config/mocha-neon/palette.sh` — the single source of truth for every Mocha Neon surface Greg owns (btop, zed, ghostty, superfile, obsidian, sketchybar…). If that file changes, this changes.

| Token | Hex | Used for |
|---|---|---|
| `--crust` | `#11111B` | scrim colour |
| `--mantle` | `#181825` | `--bg`, the deck ground |
| `--base` | `#1E1E2E` | inner surfaces of diagram nodes |
| `--surface` | `#232332` | cards, metrics, embeds — interpolated between mantle and surface0 so panels sit *above* the aurora |
| `--s0` / `--s1` / `--s2` | `#313244` / `#45475A` / `#585B70` | secondary surface, borders, muted borders |
| `--mauve` | `#B347FF` | `--primary`; arrows, rails, glow |
| `--lavender` | `#9580FF` | branch names, bar gradients |
| `--pink` | `#FF80BF` | third aurora blob, gradient midpoints |
| `--red` | `#FF6B9D` | `--bad`; costs, failures, "don't" |
| `--peach` | `#FF8C42` | gradient stops |
| `--yellow` | `#FFD700` | `--warn`; caveats, quote rail |
| `--green` | `#50FA7B` | `--good`; upside, "do it" |
| `--sky` | `#8BE9FD` | `code`, commands, second aurora blob |
| `--blue` | `#8AB4F8` | bar gradients |
| `--fg` / `--muted` | `#F0F0FF` / `#A6ADC8` | text, secondary text |

Semantic mapping: `--good` = green, `--bad` = red, `--warn` = yellow, `--primary` = mauve. Use the semantic name in components, not the raw colour, so a palette swap is one edit.

`--lift` is the elevation shadow (`0 10px 30px -12px rgba(0,0,0,.85)` plus a tight second layer). Every panel that must read above the aurora carries it.

## Type

System stack only — no webfonts, because the deck must work offline and the Artifact CSP blocks font CDNs.

- `--font-h` — `ui-sans-serif, -apple-system, 'SF Pro Display'…` for `h1`/`h2`/`h3`, tight negative tracking.
- `--font-b` — system sans for body.
- `--font-m` — `ui-monospace, 'SF Mono', Menlo…` for eyebrows, branch names, commands, diagram labels, counters.

Every size is a `clamp()` against `vw`, so the deck scales from 1280×720 to 4K without breakpoints. `h1` is capped at 49px — it was reduced twice because two-line headlines overflowed 720p.

Space Grotesk was tried and dropped: it renders too wide, and relying on a locally-installed font is a silent-fallback trap.

## Structure

- `.slide-deck` — letterboxes to 16:9 on desktop; `isolation: isolate` so the aurora can't bleed out.
- `.slide` — absolutely positioned, `background: transparent` (the aurora shows through), `z-index: 1`.
- `.slide::before` — the contrast scrim: a dark radial ellipse, opaque in the middle, fading to nothing at the edges. This is what keeps diagrams legible while the aurora stays bright in the corners.
- `.slide-content` — max-width 1180px, flex column with `gap`. **All slide content goes in here** — the overflow check measures its children.
- `.slide.center` — centres and centre-aligns, for hero and closing slides.
- `data-tag` on each slide — shows top-right and in the phone remote. Keep it to a few words.

## Components

| Class | Shape | Use for |
|---|---|---|
| `.eyebrow` / `.eyebrow.r` | small mono caps, mauve / red | section label above the heading |
| `.lead` | larger muted paragraph | the one-sentence framing under a heading |
| `.foot` | small muted paragraph | source, caveat, takeaway line |
| `.grad` / `.grad-r` | animated gradient text | half a headline — never a whole one |
| `.grid` + `.g2`/`.g3`/`.g4` | responsive card grid | 2–6 cards |
| `.card` + `.good`/`.bad`/`.warn`/`.pri` | panel with a pulsing neon left edge | a claim plus two sentences |
| `.metrics` + `.metric` | big-number tiles; `.bad-n`/`.warn-n` colour the digit | 2–4 headline numbers |
| `blockquote` + `.attr` | yellow-railed quote panel | **verbatim** quotes only |
| `.embed` + `.embed-head` | framed panel with traffic-light dots and a caption, plus a slow light sweep | wraps any diagram |
| `.diagram-wrap` + `.diagram-panel` (`.panel-before`/`.panel-after`) | two-column before/after; `.diagram-node`, `.diagram-box`, `.diagram-row`, `.diagram-muted` | a mechanism with a before and an after |
| `.loop` + `.loop-step` (`.hot`) + `.loop-arrow` (`.back`) | horizontal causal chain, pulsing arrows | "A forces B forces C, repeat" |
| `.stack` + `.node` (`.base`) + `.arrow` | vertical layer chain, `.br` for the mono name, `.desc` for prose | layers, stacks, hierarchies |
| `.split` + `.col-head` + `.tag.yes`/`.tag.no` + `.list`/`.list.r` | two-sided comparison | when-yes / when-no |
| `.bars` + `.bar-row` + `.bar-fill` (`.hot`) | horizontal bars, animated gradient | a trend over 4–8 buckets |
| `.diff` + `.diff-line` (`.add`/`.del`/`.ctx`) + `.annot-item` | side-by-side code with pinned notes | showing the load-bearing lines |
| `.tree` + `.tree-row` + `.tree-tag` (`.m`/`.a`) | file list with change flags | the footprint of a change |
| `.gh-row` + `.gh-mark` + `.gh-repo` + `.cmd` | inline GitHub mark, repo name, copyable command | where to get the thing |
| `.pill` (`.p`/`.r`/`.g`) | small mono chip | status, size, section marker |
| `.rule` | hairline | separating a takeaway from the body |

The GitHub mark is an inline SVG path in the template — keeps the deck self-contained.

## Motion

| Animation | What moves | Notes |
|---|---|---|
| `drift1/2/3` | three aurora blobs | 13 s / 16 s / 20 s, large translate + scale, `mix-blend-mode: screen` |
| `flow` | gradient text, bars, progress bar | 300% background-size scrolling |
| `neonPulse` | gradient headlines, metric digits | drop-shadow breathing |
| `edgePulse` | card left edges, chain arrows | opacity 0.55→1, staggered |
| `sweep` | light pass across `.embed` | 7 s |
| `fadeUp` | direct children of `.slide-content` on slide entry | staggered delays 1–5 |

Rules learned the hard way:

- **No `prefers-reduced-motion` blanket.** Greg runs macOS Reduce Motion, so it kills everything. `body.calm` on `C` is the escape hatch.
- `fadeUp` targets `.slide.active .slide-content > *`, which **beats** any `animation` you put on a direct child. Animate a descendant.
- Never pulse `opacity` on text containers. Arrows and rails only.
- Aurora bright + scrim strong is the working combination. Dimming the aurora to fix legibility was tried and Greg rejected it — the background stopped reading as animated.

## Keys

`→`/`space`/click next · `←` back · `Home`/`End` jump · `C` toggles `body.calm`.

When served by `deck-serve`, the page also opens an SSE channel to `/events` and accepts `next`/`prev`/`first`/`last`/`goto`/`calm`. The client is guarded by `location.protocol.startsWith('http')`, so it is inert on `file://` — and must be deleted entirely from the Artifact copy, where `https` would make it retry forever against a server that isn't there.
