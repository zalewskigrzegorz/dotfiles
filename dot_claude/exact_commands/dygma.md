---
description: Edit or inspect Greg's Dygma Defy keyboard layout (Bazecor). Loads the full decode/edit workflow on demand — not a skill, so it stays out of context until invoked.
---

# /dygma — Dygma Defy layout

## Hardware & files

- Dygma Defy wireless, configured in Bazecor. Working file: the newest `Untitled*.json` where Greg points the export (Bazecor › Preferences › Backups › Export, `~/Desktop/Untitled.json` since 2026-10; ask or take the newest, don't assume, 0b5f17ca). `~/Raise/Backups/` is stale; check where auto-backups go before relying on them.
- Edit **surgically**: string-replace the `data` of `keymap.custom` / `colormap.map` / `palette`; superkeys = `superkeys.map` + matching `neuron.superkeys[].actions`. Everything else byte-identical.
- Greg flashes himself (Load backup → the file); you can't from the CLI. Tell him to import BEFORE he re-exports, or his export clobbers your edits.
- Decoder + format notes: `~/Code/personal/bazgroly/dotfiles/notes/dygma-decoder.py`. Cheat-sheet: `bin/dygma-cheats` (Mouse+win `?`).

## Division of labour

- **Bindings → Claude** (proposed, then OK'd: function changes always ASK FIRST, "pokaż który, sam sobie zmienię"). Matrix: index = `row*16 + col`, 80 keys/layer, 10 layers (800 ints); left cols 0–6, right 9–15, 7–8 gap, row 4 = thumbs.
- **Colors → Greg in Bazecor.** The colormap LED→key mapping is buggy (`led_index_BUGGY`): never write colors programmatically; propose, he applies.

## Keycodes (Kaleidoscope)

- Modified = `base_HID + (flag << 8)`; LCtrl=1, LAlt=2, RAlt=4, LShift=8, LGui=16 (`Cmd+Shift+1` = 6174).
- `0` NoKey (black), `65535` Transparent (red = "return"). OneShotLayer = 49161+layer, OSM mods 49153–49160. Mouse 20480–20620 (move 20481/2/4/8 U/D/L/R; buttons 20545/6/8 L/R/M; 20552/20560 back/fwd; 20497/8 wheel). Consumer ≈ 18000–24000.
- **Superkeys:** code = **53980 + id** (not 53852). `superkeys.map` = 5 actions + `0` per superkey, then 65535 padding; slots [tap, hold, tap&hold, 2×tap, 2×hold]. Greg can't trigger tap&hold / 2×hold: keep them `1`. 54108/54109 = BT-pair / Battery.

## Layers (2026-06-16)

L0 Main · L1 Arrows+numpad · L2 Media+fn · L3 Mouse+win; L4–L9 stay empty (he won't remember more). Thumb cluster identical on every layer; on layer N the OneShotLayer(N) key + transparents are red. L3: move `@E/S/D/F`, scroll `@3/@C`, back/fwd `@W/@R`, clicks `@H/@J/@K`, `@Q` Wooshy (Ctrl⌘/), `@A` kindaVim (Ctrl[), `@?` cheat-sheet (Ctrl⌥/). Mouse: `speed`=1, `accelSpeed`=24, `speedLimit`=96.

## Superkeys (Bazecor shows 1-indexed: "Super 7" = id 6, "Super 8" = id 7, his leader key; don't repurpose without asking)

| # | name | tap | hold | 2×tap |
|---|---|---|---|---|
| 0 | AI | Raycast (⌘Space) | AI light-rewrite (⌘G) | AI grammar (⇧⌘G) |
| 1 | Paste | paste | Raycast clipboard | 1Password search |
| 2 | Revert | undo | select-all | redo |
| 3 | Copy | copy | AI translate | free |
| 4 | vs autocomplete | autocomplete | AI hard-rewrite (⌃⌘G) | read selection (⌥Esc) |
| 5 | Read reset talk | reset layers | free | Slack search |
| 6 | Windows | overview (⌃⌘L, ⌃⌥Space) | Wooshy (⌃⌘/) | kindaVim Normal (⌃[) |
| 7 | leaders | tuios prefix (⌃Space) | free | free |

AI prompts live in Raycast AI commands (cheap fast model for grammar/light).

## Colors — Mocha Neon (W=0; true OFF = `0 0 0 0`; high W washes colors)

red `#FF0044` · green `#00FF66` · cyan `#00E5FF` · gold `#FFCC00` · orange `#FF5500` · mauve `#B300FF` · blue `#0033CC` · pink `#FF00AA`. ESC white · superkeys mauve · letters blue · symbols cyan · modifiers gold · Control/Space/Tab/Enter green · DEL/X/Bksp red · screenshot pink · layer buttons orange · NoKey black · Transparent red · numpad his. Check ΔE between neighbouring groups before showing a new palette (0b5f17ca).

## Workflow

Read and decode → propose → his OK for function changes → surgical edit → tell him to import. Colors: propose, he applies. After big changes offer to commit the export to dotfiles.

## Halves stuck in bootloader (`isBootloader: true`)

From Dygma support (2026-10-21), unverified past "Enable Features" (fa747937). Greg runs every step; never flash for him.
1. Export a backup, quit Bazecor.
2. Support's FlasherTools (arm64 dmg, `codesign -dv` → `TeamIdentifier=2X7P6KJ6LJ`) + "Sides loader Defy" folder.
3. Menu bar › Advanced › Enable Features (then "Skip serial number input" and the folder picker appear): outer folder, tick Force sides flash, Flash Neuron, then Flash Sides.
4. Press each half's red corner key until green.
5. Bazecor firmware update, then Load Backup.

$ARGUMENTS
