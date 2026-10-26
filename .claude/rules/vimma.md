---
paths:
  - "dot_config/private_vimma/**"
  - "run_onchange_after_39-vimma-userchrome-sync.sh.tmpl"
---

# Vimma

- **Quote a shortcut only from the uncommented lines** of `[keys]` and `[modal]`.
  The stock comments describe Vimma's defaults: `ctrl+b ?` from the header was
  wrong, the live prefix is `ctrl+space` (56251e09). Prefix works in every
  mode; leader `" "` only in normal mode and the side panel, so `<leader>?` in
  `show_keybinds` means `spacja ?`.
- **Vimma's own keymap and guide** live in
  `/Applications/Vimma.app/Contents/Resources/browser/omni.ja`
  (`chrome/browser/content/browser/vimma/core/keymap.mjs`). Unzip it into the
  scratchpad, never next to the app.
- **Hints:** colour is `[theme.colors] bright_green` (hints only, the letter
  colour is picked by Vimma). The size is hard-coded at 11px; the override is
  `userChrome.css` (`#vimma-hints .vimma-hint`), copied to both profiles by
  stage 39 together with the `user.js` pref. Selectors can change in an
  update: after one, check the 14px still applies (7c37679b).
- **Reload:** `config.toml` reloads live (`:source`); CSS and `user.js` need ⌘Q
  and a reopen.
- **Tab chords are `cmd+alt+←/→`**: plain Ctrl belongs to HyprMac. Mouse tilt
  is Logi Options+ "Scroll left/right", remapped to Back/Forward by hand.
  Options+ settings are not in dotfiles; the cask's app opens with
  `open-here -a logioptionsplus`.
- **A key for a web page** (pause on YouTube): check Vimma's normal-mode keymap
  first (`core/defaults.mjs`, `core/keymap.mjs` in `omni.ja`); `k`, `j` and
  `space` are taken (673e7d5e: "`k` pauzuje" was wrong).
- **Vimma's version** comes from `vimma-ctl` or the app plist, never from the
  Firefox version (an issue went out as 158.0.1 instead of 0.1.8). Issues go to
  `vimma-browser/vimma` per its `bug_report.yml`; `:bug` copies a report.
- **`:restart` closes Vimma and does not reopen it**: `open-here -a Vimma`.
- **One action per key**: "open and switch" in one key is not possible (#533);
  the workaround is `F`, the hint letters, then `L`. `H`/`L` switch tabs.
- **Userscripts** live in `dot_config/private_vimma/userscripts/`, installed
  through Tampermonkey; YouTube's space is off via `youtube-space-no-play.user.js`.
