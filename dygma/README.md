# Dygma Defy layout

Canonical export of the **Dygma Defy** ("Defy red devil") keyboard layout,
versioned here so the config survives a reinstall.

- `defy-layout.json` — full Bazecor backup (keymap, colors, macros, superkeys, mouse settings).

## Restore on a new machine
The Defy can only be flashed by **Bazecor over serial** — there's no CLI flash,
so `chezmoi apply` cannot do it automatically. Manual step:

1. Open **Bazecor**, connect the Defy.
2. Copy `defy-layout.json` to the Bazecor backup folder (`~/Raise/Backups/`).
3. **Load backup** → select it → flash.

## Editing
Use the `/dygma` slash command — it loads the full decode/edit workflow.
Runtime cheat-sheet: `dygma-cheats` (or aerospace `ctrl-alt-/`, or Mouse+win `?`).
Decoder reference: `~/Code/personal/bazgroly/dotfiles/notes/dygma-decoder.py`.
