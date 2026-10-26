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
