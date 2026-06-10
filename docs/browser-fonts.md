# Fonts — canonical a11y setup (system-wide)

## TL;DR matrix

| Domain | Font | Role |
|---|---|---|
| **All code / monospace** (terminal, editors, sketchybar, tmux, code blocks) | `JetBrainsMono Nerd Font` | locked 2026-05-23, re-confirmed 2026-06-10 |
| **Browser body / prose / headings** | `Atkinson Hyperlegible Next` | locked 2026-06-10 |
| **Browser serif** (sites forcing `font-family: serif`) | `Verdana` | evidence-backed, visually distinct from Atkinson |
| **Browser sans-serif** (most sites) | `Atkinson Hyperlegible Next` | locked |
| **Slack** | `/slackfont Atkinson Hyperlegible Next` | reverts on session expiry — re-run when it resets |
| **Spacing (the real lever)** | `letter-spacing 0.12em` + `word-spacing 0.16em` + `line-height 1.5` | tier-A evidence, applied in userstyles |

## History / rationale

**2026-06-10 research run replaced OpenDyslexic with Atkinson Hyperlegible Next**
for all body text. Full research (7 items, evidence tiers, per-field JSON):
`~/Code/personal/bazgroly/dotfiles/research/fonts-adhd-dyslexia/report.md`.

Key findings:

- OpenDyslexic's only independent RCT (Wery & Diliberto 2017) is **negative** —
  no speed/accuracy benefit. Tier C/D otherwise. It also has no variable
  weight axis, so it can't do the dark-mode ~350 weight trick.
- The only tier-A intervention is **spacing**, not letterforms (Zorzi 2012,
  PNAS: ~50% fewer errors in dyslexic readers; codified in WCAG 1.4.12).
- Atkinson Hyperlegible Next has no RCTs (too new, Feb 2025) but the best
  letterform-distinction mechanics (I/l/1, O/0, b/d/p/q), large x-height and
  a variable wght axis 200–800.
- Evidence-backed fallback if Atkinson subjectively doesn't click after a
  week: **SF Pro / Verdana** (Rello & Baeza-Yates 2013; Readability Group
  survey ~2500 participants) — zero-install on macOS.
- **JetBrains Mono stays** for code: ligatures are a hard requirement
  (eliminates Atkinson Hyperlegible Mono — intentionally ligature-free);
  Monaspace's texture healing has no empirical validation and weak
  variable-font support in editors.

**Do not propose alternative fonts** (Lexend, Iosevka, Fantasque, Monaspace,
Dyslexie, Comic Neue, etc.) without being asked — these picks won the
2026-06-10 evidence-tier bake-off.

## Settings → Appearance → Fonts (apply identically in every browser)

| Slot | Font | Rationale |
|---|---|---|
| **Standard font** | `Atkinson Hyperlegible Next` | proportional, body text |
| **Serif font** | `Verdana` | sites forcing serif get the evidence-backed sans instead; visually distinct from Atkinson so sites stay distinguishable |
| **Sans-serif font** | `Atkinson Hyperlegible Next` | main body font |
| **Fixed-width font** | `JetBrainsMono Nerd Font` | locked code font |
| **Mathematical font** | `Atkinson Hyperlegible Next` | keep family consistent |
| **Minimum font size** | bump 1 notch from `Tiny` | ADHD eye-strain reduction |

## Per-browser entry points

| Browser | Path |
|---|---|
| Comet | `comet://settings/fonts` |
| Chrome | `chrome://settings/fonts` |
| Edge | `edge://settings/fonts` |
| Firefox / Firefox Dev | Preferences → General → Language and Appearance → Fonts → Advanced |
| Safari | Preferences → Advanced → Accessibility → "Never use font sizes smaller than" + per-site override via Reader |

## Slack

```
/slackfont Atkinson Hyperlegible Next
```

Caveats: desktop-only, Latin chat text only (code blocks keep Slack's mono),
**reverts on session expiry** — just re-run the command. Bare `/slackfont`
resets to default.

## Font availability

- `Atkinson Hyperlegible Next` — homebrew cask `font-atkinson-hyperlegible-next`
  (in `dot_Brewfile.tmpl`). No Nerd Font patch needed (body text only).
- `JetBrainsMono Nerd Font` — cask `font-jetbrains-mono-nerd-font`.
- `Verdana` / `SF Pro` — ship with macOS, zero install.
- OpenDyslexic Nerd Font variants remain installed (cask
  `font-opendyslexic-nerd-font`) as legacy fallback; safe to drop later.

## Dark mode (Mocha Neon) tuning

Light text on `#1E1E2E` optically bolds itself (irradiation). Atkinson Next is
a variable font — drop prose to **wght ~350** in dark mode where possible
(done in the GitHub userstyle for `.markdown-body p/li`). Never force weight
with `!important` or `<strong>`/headings lose their emphasis.

## When NOT to override

- New browser install — apply this exact table, do not suggest other fonts.
- Any "the design looks broken" complaint from a site — accessibility wins.
- Reader/print views — leave the browser's reader mode alone, it has its own typography.

## When you CAN override

- Explicit user request.
- A single site via Stylus extension userstyle, if a particular site renders
  the font stack unreadable.

## Per-site userstyle overrides (Stylus)

| Site | Userstyle file | What it forces |
|---|---|---|
| github.com | `dot_config/stylus/github-mocha-neon-override.user.css` | Mocha Neon palette + body=Atkinson Hyperlegible Next (0.12em/0.16em/1.5 spacing, wght 350 prose), code=JetBrainsMono |

After editing the source file, re-import / update the style inside the Stylus
extension — chezmoi only syncs the repo copy to `~/.config/stylus/`, the
browser extension does not read that path by itself.

## Code font preference

Stack for any "code" / monospace usage in browser userstyles, terminal, editor:

```css
font-family: "JetBrainsMono Nerd Font", "JetBrains Mono",
             ui-monospace, "SFMono-Regular", Menlo, monospace;
```

Primary = JetBrainsMono Nerd Font (Nerd Font glyphs required for sketchybar /
tmux / statusline). `"JetBrains Mono"` fallback is the no-glyph variant for
machines without the Nerd Font cask installed.
