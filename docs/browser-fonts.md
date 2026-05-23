# Fonts — canonical a11y setup (system-wide)

## TL;DR matrix

| Domain | Font | Role |
|---|---|---|
| **All code / monospace** (terminal, editors, sketchybar, tmux, code blocks) | `JetBrainsMono Nerd Font` | locked 2026-05-23 |
| **Browser body / prose / headings** | `OpenDyslexicM Nerd Font Propo` | locked |
| **Browser serif** (sites forcing `font-family: serif`) | `OpenDyslexicAlt Nerd Font Propo` | locked |
| **Browser sans-serif** (most sites) | `OpenDyslexicM Nerd Font Propo` | locked |
| **Browser mathematical** | `OpenDyslexicM Nerd Font Propo` | locked |

## Browser fonts — canonical a11y setup

**Greg's accessibility-locked font setup for every Chromium / Firefox / Safari
install.** Tested under ADHD + dyslexia. Do not change without explicit override.

OpenDyslexic was hand-picked after testing. **JetBrains Mono** is the locked
code font everywhere (terminal, editors, sketchybar, code blocks in browser) —
2026-05-23 research run reversed the earlier Iosevka pick. **Do not propose
alternative fonts** (Atkinson, Lexend, Verdana, Iosevka, Fantasque, etc.)
without being asked — these picks already won the bake-off.

## Settings → Appearance → Fonts (apply identically in every browser)

| Slot | Font | Rationale |
|---|---|---|
| **Standard font** | `OpenDyslexic Nerd Font Propo` | proportional, body text |
| **Serif font** | `OpenDyslexicAlt Nerd Font Propo` | Alt variant — slightly different letter shapes, used by sites forcing `font-family: serif` |
| **Sans-serif font** | `OpenDyslexicM Nerd Font Propo` | M variant for sans-serif sites |
| **Fixed-width font** | `JetBrainsMono Nerd Font` | post-Iosevka research pick — won the latest dyslexia bake-off |
| **Mathematical font** | `OpenDyslexicM Nerd Font Propo` | keep family consistent |
| **Minimum font size** | bump 1 notch from `Tiny` | ADHD eye-strain reduction |

## Per-browser entry points

| Browser | Path |
|---|---|
| Comet | `comet://settings/fonts` |
| Chrome | `chrome://settings/fonts` |
| Edge | `edge://settings/fonts` |
| Firefox / Firefox Dev | Preferences → General → Language and Appearance → Fonts → Advanced |
| Safari | Preferences → Advanced → Accessibility → "Never use font sizes smaller than" + per-site override via Reader |

## Font availability

All four OpenDyslexic Nerd Font variants + Iosevka Nerd Font are installed under
`~/Library/Fonts/`. On a fresh machine they come from the homebrew cask
`font-open-dyslexic-nerd-font` + `font-iosevka-nerd-font` (already in
`dot_Brewfile.tmpl`).

## Why three different OpenDyslexic variants?

Sites use CSS `font-family: <serif|sans-serif>` to pick a generic family. By
mapping each generic to a *slightly different* OpenDyslexic variant (Propo /
AltPropo / MPropo), text on different sites stays visually distinguishable
without losing OpenDyslexic's dyslexia-friendly letter shapes. If you ever feel
"every site looks identical", that's the variant differentiation working.

## When NOT to override

- New browser install — apply this exact table, do not suggest other fonts.
- Any "the design looks broken" complaint from a site — accessibility wins.
- Reader/print views — leave the browser's reader mode alone, it has its own typography.

## When you CAN override

- Explicit user request ("daj tu Atkinson zamiast OpenDyslexic" → fine).
- A single site via Stylus extension userstyle, if a particular site renders
  OpenDyslexic unreadable.

## Per-site userstyle overrides (Stylus)

For daily-driver sites where you want OpenDyslexic + neon palette but the
site's own font stack blocks generic-family fallback (Apple system / Mona Sans
/ Inter loaded by site), use a Stylus userstyle to force it.

| Site | Userstyle file | What it forces |
|---|---|---|
| github.com | `dot_config/stylus/github-mocha-neon-override.user.css` | Mocha Neon palette override + body=OpenDyslexicM, code=JetBrainsMono |

## Code font preference

Stack for any "code" / monospace usage in browser userstyles, terminal, editor:

```css
font-family: "JetBrainsMono Nerd Font", "JetBrains Mono",
             ui-monospace, "SFMono-Regular", Menlo, monospace;
```

Primary = JetBrainsMono Nerd Font (Nerd Font glyphs required for sketchybar /
tmux / statusline). `"JetBrains Mono"` fallback is the no-glyph variant for
machines without the Nerd Font cask installed.
