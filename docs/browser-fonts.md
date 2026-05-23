# Browser fonts — canonical a11y setup

**Greg's accessibility-locked font setup for every Chromium / Firefox / Safari
install.** Tested under ADHD + dyslexia. Do not change without explicit override.

OpenDyslexic was hand-picked after testing; Iosevka was hand-picked for code
readability over JetBrains Mono. **Do not propose alternative fonts** (Atkinson,
Lexend, Verdana, etc.) without being asked — these picks already won the test.

## Settings → Appearance → Fonts (apply identically in every browser)

| Slot | Font | Rationale |
|---|---|---|
| **Standard font** | `OpenDyslexic Nerd Font Propo` | proportional, body text |
| **Serif font** | `OpenDyslexicAlt Nerd Font Propo` | Alt variant — slightly different letter shapes, used by sites forcing `font-family: serif` |
| **Sans-serif font** | `OpenDyslexicM Nerd Font Propo` | M variant for sans-serif sites |
| **Fixed-width font** | `Iosevka Nerd Font Propo` | hand-picked over JB Mono after dyslexia testing |
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
| github.com | `dot_config/stylus/github-mocha-neon-override.user.css` | Mocha Neon palette override + body=OpenDyslexicM, code=FantasqueSansMono→Iosevka |

## Code font preference

Stack for any "code" / monospace usage in browser userstyles:

```css
font-family: "FantasqueSansMono Nerd Font", "FantasqueSansM Nerd Font",
             "Fantasque Sans Mono", "Iosevka Nerd Font Propo",
             "Iosevka Nerd Font", ui-monospace, "SFMono-Regular", Menlo, monospace;
```

Primary = FantasqueSansMono, fallback = Iosevka. Order matters — list naming
variants together because Nerd Font PostScript names differ across distros.
