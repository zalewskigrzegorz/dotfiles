# Mocha Neon — Insomnia plugin theme

Forked from Dracula PRO Insomnia plugin; all hex bumped to Mocha Neon palette
(`docs/mocha-neon-palette.md`).

## Install

1. Insomnia → **Application → Preferences → Plugins → Reveal Plugins Folder**.
2. The `run_onchange_after_44-insomnia-plugins-sync.sh.tmpl` hook copies this
   directory there automatically on `chezmoi apply`. Manual fallback:
   `cp -r ~/.config/insomnia/plugins/insomnia-plugin-theme-mocha-neon <plugins-folder>/`.
3. Restart Insomnia.
4. Preferences → **Themes** → select **Mocha Neon**.

## Token mapping (Dracula PRO → Mocha Neon)

| Token | Dracula | Mocha Neon |
|---|---|---|
| background.default | `#22212C` | `#1E1E2E` |
| foreground.default | `#F8F8F2` | `#F0F0FF` |
| highlight | `#7970A9` (overlay) | `#B347FF` (mauve, for pop) |
| success | `#8AFF80` | `#50FA7B` |
| notice | `#FFCA80` | `#FF8C42` |
| warning | `#FFFF80` | `#FFD700` |
| danger | `#FF9580` | `#FF6B9D` |
| surprise | `#9580FF` | `#B347FF` (mauve) |
| info | `#80FFEA` | `#8BE9FD` |
| sidebar bg | `#151320` | `#181825` (Catppuccin mantle) |
| dialog bg | `#2B2640` | `#2A2A3A` |
