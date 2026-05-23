# Mocha Neon — Tier 2 GUI app checklist

Each Tier 2 app must render the **Mocha Neon** palette (bumped neon variant of
Catppuccin Mocha) to match the cyberpunk vibe of Tier 1. Vanilla pastel
Catppuccin is NOT acceptable.

**Acceptance rule:** screenshot must visibly show mauve `#B347FF` OR pink
`#FF80BF` as an accent. If it reads "pastel", the row stays open.

Screenshots: `~/Code/personal/bazgroly/dotfiles/screenshots/mocha-neon-tier2/<app>.png`

## Strategy per app type

- **Apps with full theme override** (Cursor / Obsidian / Spicetify / DataGrip / Stylus): install Catppuccin Mocha port, then override 11 accent tokens with bumped hex.
- **Apps with JSON theme paste** (Slack / Firefox Color): hand-author JSON from `docs/mocha-neon-palette.md`, do NOT paste catppuccin/<app>'s vanilla payload.
- **Apps with limited theming** (Raycast / VLC / Comet / Insomnia): apply closest port available, file upstream issue for override support, or fork locally.

## Checklist

- [ ] **Raycast** — Settings → Themes → Catppuccin Mocha. Override unavailable → file upstream issue. Accept pastel as interim. Screenshot: `mocha-neon-tier2/raycast.png`.
- [ ] **Slack** — Preferences → Sidebar → Custom → paste Mocha Neon hex sequence (see palette doc for sidebar role order). Screenshot: `mocha-neon-tier2/slack.png`.
- [ ] **Cursor** — Extensions → Catppuccin for VSCode → Mocha. Then `~/Library/Application Support/Cursor/User/settings.json` workbench.colorCustomizations: override 11 tokens. Screenshot: `mocha-neon-tier2/cursor.png`.
- [ ] **Obsidian** — Settings → Appearance → Themes → Catppuccin. Custom CSS snippet (Settings → Appearance → CSS snippets) with the 11 token overrides. Screenshot: `mocha-neon-tier2/obsidian.png`.
- [ ] **Spotify (Spicetify)** — `spicetify install catppuccin && spicetify config current_theme catppuccin && spicetify apply`. Edit `~/.config/spicetify/Themes/catppuccin/color.ini` `[Frappe]` (or active flavor) section with bumped hex. Re-`spicetify apply`. Screenshot: `mocha-neon-tier2/spotify.png`.
- [ ] **Firefox Developer Edition** — Firefox Color extension → import Mocha Neon JSON (hand-authored from palette doc). Screenshot: `mocha-neon-tier2/firefox.png`.
- [ ] **Google Chrome** — Stylus extension → import Mocha Neon userstyle (fork of catppuccin/userstyles with bumped hex). Screenshot: `mocha-neon-tier2/chrome.png`.
- [ ] **DataGrip** — Settings → Plugins → Catppuccin Theme → Mocha. Settings → Editor → Color Scheme: override 11 tokens. Screenshot: `mocha-neon-tier2/datagrip.png`.
- [ ] **VLC** — manual import (limited theming support). Accept closest approximation. Screenshot: `mocha-neon-tier2/vlc.png`.
- [ ] **Insomnia** — Preferences → Themes → Catppuccin Mocha. Check if 11-token override is exposed; if not, file upstream. Screenshot: `mocha-neon-tier2/insomnia.png`.
- [ ] **Comet** — Chromium-based → use Chrome Stylus path. If not Chromium, TBD. Screenshot: `mocha-neon-tier2/comet.png`.

## Out of scope until upstream fixes land

- Apps without theming support at all (most macOS native apps) — accept system appearance.
