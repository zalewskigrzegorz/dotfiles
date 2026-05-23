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
  - **Reunite** (REDACTED_ORG's client, 4-color custom theme + Window gradient toggle) → `mocha-neon-reunite.json`. Reunite uses a different model: `systemNavigation`, `selectedItems`, `presenceIndication`, `notifications`. Paste each hex into the matching color picker under Preferences → Appearance → Custom theme; leave **Window gradient** checked.
  - Screenshot: `mocha-neon-tier2/slack.png`.
- [x] **Cursor** — Catppuccin for VSCode extension installed + theme set to "Catppuccin Mocha". `workbench.colorCustomizations` + `editor.tokenColorCustomizations` blocks merged into `~/Library/Application Support/Cursor/User/settings.json` (chezmoi-managed via `dot_config/cursor/User/settings.json` + `run_onchange_after_38` hook syncs to the Library path on every apply). Screenshot: `mocha-neon-tier2/cursor.png`.
- [ ] **Obsidian** — Settings → Appearance → Themes → Catppuccin. Custom CSS snippet (Settings → Appearance → CSS snippets) with the 11 token overrides. Screenshot: `mocha-neon-tier2/obsidian.png`.
- [ ] **Spotify (Spicetify)** — `spicetify install catppuccin && spicetify config current_theme catppuccin && spicetify apply`. Edit `~/.config/spicetify/Themes/catppuccin/color.ini` `[Frappe]` (or active flavor) section with bumped hex. Re-`spicetify apply`. Screenshot: `mocha-neon-tier2/spotify.png`.
- [ ] **Firefox Developer Edition** — Firefox Color extension → import Mocha Neon JSON (hand-authored from palette doc). Screenshot: `mocha-neon-tier2/firefox.png`.
- [⚠️] **Google Chrome / Comet** — Mocha Neon Chromium theme extension forked from Dracula PRO. Repo source: `dot_config/chrome/themes/mocha-neon/manifest.json` (unpacked, `manifest_version: 2`).
  - **Vanilla Chrome:** load via `chrome://extensions` → Developer mode → Load unpacked. Covers tabs/toolbar/omnibox/NTP. Works.
  - **Comet (Perplexity Chromium):** loads only **MV3** themes (`manifest_version: 3`). MV2 themes are silently ignored. Theme does NOT appear in `comet://extensions` list or `Settings → Appearance → Themes` UI — but the bumped accent IS visible. Confirm by toggling profile color to "default": if the mauve accent disappears, the theme isn't loaded; if it stays, ✅.
  - **Profile color preset:** stack with the unpacked theme — `purple` preset is the closest profile-accent match for Mocha Neon mauve.
  - Screenshot: `mocha-neon-tier2/chrome.png`.
- [⚠️] **DataGrip / JetBrains IDEs** — Catppuccin plugin already installed. Set:
  - **UI Theme:** Settings → Appearance & Behavior → Appearance → Theme → "Catppuccin Mocha" (or "Islands Catppuccin Mocha" — Islands variant adds tab/pane styling).
  - **Editor color scheme:** Settings → Editor → Color Scheme → "Catppuccin Mocha" (NOT Latte/Frappé/Macchiato).
  - Both vanilla Catppuccin pastel → **bumped Mocha Neon accents parked** (would need custom JB plugin .theme.json + Kotlin packaging — out of scope here). ICLS-only override attempts failed to validate in JB 2025.1.
  - Repo: `dot_config/jetbrains/MochaNeon.icls` (saved for later refinement when bumped JetBrains scheme is feasible).
  - Screenshot: `mocha-neon-tier2/datagrip.png`.
- [ ] **VLC** — manual import (limited theming support). Accept closest approximation. Screenshot: `mocha-neon-tier2/vlc.png`.
- [x] **Insomnia** — Mocha Neon plugin theme forked from Dracula PRO. Repo source: `dot_config/insomnia/plugins/insomnia-plugin-theme-mocha-neon/`. `run_onchange_after_44-insomnia-plugins-sync` rsyncs every plugin into `~/Library/Application Support/Insomnia/plugins/` on apply. Activate via Preferences → Plugins (ensure `insomnia-plugin-theme-mocha-neon` enabled) → Themes → **Mocha Neon**. Screenshot: `mocha-neon-tier2/insomnia.png`.
- [⚠️] **Comet** — Chromium-based, very limited theming. Investigated 2026-05-23:
  - **Browser chrome:** Comet only offers 12 preset profile-accent colors (no custom hex picker, no `userChrome.css` — Chromium doesn't support that). Closest to Mocha Neon mauve = **purple** preset. Accept as interim.
  - **Browser theme:** Mocha Neon unpacked extension at `dot_config/chrome/themes/mocha-neon/` — load via `comet://extensions` → Developer mode → Load unpacked. Replaces Catppuccin pastel with bumped neon. Covers tab/toolbar tint without forking a `.crx`.
  - **Page-level (GitHub / YouTube / etc.):** install **Stylus** extension + import userstyles from `github.com/catppuccin/userstyles`. Patch hex with Mocha Neon manually per userstyle if pastel reads wrong.
  - Screenshot: `mocha-neon-tier2/comet.png`.

## Out of scope until upstream fixes land

- Apps without theming support at all (most macOS native apps) — accept system appearance.
