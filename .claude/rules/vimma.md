---
paths:
  - "dot_config/private_vimma/**"
  - "userscripts/**"
  - "run_onchange_after_39-vimma-userchrome-sync.sh.tmpl"
---

# Vimma

- **Quote a shortcut only from the uncommented lines** of `[keys]` and `[modal]`.
  The stock comments describe Vimma's defaults (`ctrl+b ?` from the header was
  wrong, the live prefix is `ctrl+space`). Prefix works in every mode; leader `" "` only in normal mode and the side panel, so `<leader>?` in
  `show_keybinds` means `spacja ?`.
- **Vimma's own keymap and guide** live in
  `/Applications/Vimma.app/Contents/Resources/browser/omni.ja`
  (`chrome/browser/content/browser/vimma/core/keymap.mjs`). Unzip it into the
  scratchpad, never next to the app.
- **Hints:** colour is `[theme.colors] bright_green` (hints only, the letter
  colour is picked by Vimma). The size is hard-coded at 11px; the override is
  `userChrome.css` (`#vimma-hints .vimma-hint`), copied to both profiles by
  stage 39 together with the `user.js` pref. After a Vimma update check the
  14px still applies (selectors change).
- **Reload:** `config.toml` reloads live (`:source`); CSS and `user.js` need ⌘Q
  and a reopen.
- **Tab chords are `cmd+alt+←/→`**: plain Ctrl belongs to HyprMac. Mouse tilt
  is Logi Options+ "Scroll left/right", remapped to Back/Forward by hand.
  Options+ settings are not in dotfiles; the cask's app opens with
  `open-here -a logioptionsplus`.
- **A key for a web page** (pause on YouTube): check Vimma's normal-mode keymap
  first (`core/defaults.mjs`, `core/keymap.mjs` in `omni.ja`); `k`, `j` and
  `space` are taken ("`k` pauzuje" was wrong once).
- **Vimma's version** comes from `vimma-ctl` or the app plist, never from the
  Firefox version. Issues go to
  `vimma-browser/vimma` per its `bug_report.yml`; `:bug` copies a report.
- **`:restart` closes Vimma and does not reopen it**: `open-here -a Vimma`.
- **One action per key**: "open and switch" in one key is not possible (#533);
  the workaround is `F`, the hint letters, then `K`. `J`/`K` switch tabs,
  `H`/`L` are history (Vimium parity since 2026-11-16).
- **Userscripts** live in `dot_config/private_vimma/userscripts/`, installed
  through Tampermonkey; YouTube's space is off via `youtube-space-no-play.user.js`.
  The Google Photos ones (`photos-vim`, `tiktok-to-album`, the second needs GPTK)
  sit in top-level `userscripts/`. Vimma eats `h l d u` in normal mode and its
  `[sites]` insert rule is per host, not per path, so `photos-vim` focuses a
  hidden `role=textbox` in the photo preview (Vimma goes to insert there) and
  blurs it in the grid (Vimma's hjkl again). Photos ignores synthetic keys,
  so the script clicks buttons by label; in an album the trash hides under
  "Więcej opcji". During a test Greg runs, don't drive his Photos tab.
  `youtube-vim` uses the same hidden box on `/watch` (h/l/b/w seek, j/k speed,
  `-` `=` volume, space); speed goes out as a synthetic ctrl+wheel because
  Enhancer for YouTube keeps its own copy of the rate and reapplies it.
- **A userscript change works only after Update in Tampermonkey**, and raw
  GitHub can serve the old version for ~5 min. A change to a script that shares
  a key with another bumps the version of both, and the report says which
  scripts need the update. Never announce a fix "independent of the update" while
  an older script still holds that key.
- **Greg has no usable console in Vimma.** No DevTools steps and no `copy()`.
  A probe is a userscript with `GM_registerMenuCommand` that writes its result
  to a file in `~/Downloads`, or a ready panel on the page. A locally served
  `.user.js` did not trigger the install, so install from the raw URL after the
  push, with Update.
- **"Key X does not work in Vimma"** → first the mode on a screenshot (bottom
  left corner). Single-letter keys work only in NORMAL, `Esc` returns. Reload is
  `Ctrl+R` / `F5`, hard reload `Ctrl+Shift+R` / `Ctrl+F5`.
- **An add-on options page (`moz-extension://`) is unreachable for `browsentic`**
  (`TAB_UNREACHABLE`). The source is
  `~/Library/Application Support/Vimma/Profiles/<profile>/extensions/<id>.xpi`:
  unzip it into the scratchpad, the UUID is in `prefs.js` under
  `extensions.webextensions.uuids`. Search only the profile dir (`rg` over the
  whole Application Support hits `Permission denied`). A minified file: one call
  with several `rg -o` through `rtk proxy`.
- **A key change in `youtube-vim` or `photos-vim`** updates the section "Vimma:
  YouTube i Google Photos" in the note `30 - Resources/Tech/Skróty
  Klawiszowe.md` in the same task (skill `obsidian-notes`, edit the section, no
  new note).
