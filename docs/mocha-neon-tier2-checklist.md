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

- [x] **Raycast** — Beta supports Theme Studio (Settings → Themes → Theme Studio). Built a Mocha Neon fork from the bundled Catppuccin Mocha theme. Screenshot: `mocha-neon-tier2/raycast.png`.
  - **Repo source of truth:** `dot_config/raycast/themes/mocha-neon.json`. To re-import on a fresh machine: open the file, copy contents, paste into Theme Studio's import field.
  - **One-click deeplink:** `https://themes.ray.so?version=1&name=Mocha%20Neon&author=Grzegorz%20Zalewski&authorUsername=zalewskigrzegorz&colors=%231E1E2E,%231E1E2E,%23F0F0FF,%23B347FF,%23B347FF,%23FF6B9D,%23FF8C42,%23FFD700,%2350FA7B,%238BE9FD,%239580FF,%23FF80BF&appearance=dark&addToRaycast`
  - Token order: `background, backgroundSecondary, text, selection, loader, red, orange, yellow, green, blue, purple, magenta` (matches Theme Studio sidebar order).
- [x] **Slack (standard / Reunite)** — Two flavors stored in `dot_config/slack/`:
  - **Standard Slack** (10-hex sidebar) → `mocha-neon-sidebar.txt`. Paste the comma-separated line into Preferences → Sidebar → Customize → Color Picker bottom field.
  - **Reunite** (Redocly's client, 4-color custom theme + Window gradient toggle) → `mocha-neon-reunite.json`. Reunite uses a different model: `systemNavigation`, `selectedItems`, `presenceIndication`, `notifications`. Paste each hex into the matching color picker under Preferences → Appearance → Custom theme; leave **Window gradient** checked.
  - Screenshot: `mocha-neon-tier2/slack.png`.
- [x] **Cursor** — Catppuccin for VSCode extension installed + theme set to "Catppuccin Mocha". `workbench.colorCustomizations` + `editor.tokenColorCustomizations` blocks merged into `~/Library/Application Support/Cursor/User/settings.json` (chezmoi-managed via `dot_config/cursor/User/settings.json` + `run_onchange_after_38` hook syncs to the Library path on every apply). Screenshot: `mocha-neon-tier2/cursor.png`.
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
