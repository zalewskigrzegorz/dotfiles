---
description: Edit or inspect Greg's Dygma Defy keyboard layout (Bazecor). Loads the full decode/edit workflow on demand — not a skill, so it stays out of context until invoked.
---

# /dygma — Dygma Defy layout editing

Load this when Greg wants to tweak/inspect his keyboard. Everything you need to
edit the layout competently is here. Don't make it a skill — rare use.

## Hardware & files
- **Dygma Defy wireless** ("Defy red devil"), configured via Bazecor.
- **Working file:** `~/Raise/Backups/Untitled.json` — the single current layout.
  Edit it SURGICALLY (string-replace the `data` of `keymap.custom` /
  `colormap.map` / `palette`; for superkeys edit `superkeys.map` + the matching
  `neuron.superkeys[].actions`). Keep the rest byte-identical.
- Greg flashes by **Load backup → Untitled.json** in Bazecor. You CANNOT flash
  from CLI. ⚠️ Tell Greg to import BEFORE he re-exports, or his export clobbers
  your edits.
- Auto-backups: `~/Raise/Backups/Defy/<neuronID>/<ts>-*.json` (every ~30 min) —
  use as rollback / to read the live keyboard state.
- Full decoder + format notes: `~/Code/personal/bazgroly/dotfiles/notes/dygma-decoder.py`
- Runtime cheat-sheet for Greg: `~/Code/dotfiles/bin/dygma-cheats` (aerospace `ctrl-alt-/` → choose picker; also bound to Mouse+win `?`).

## Division of labor (LEARNED THE HARD WAY)
- **Bindings / keymap → Claude.** Reliable: pure matrix, index = `row*16 + col`,
  80 keys/layer, 10 layers (800 ints in `keymap.custom`). Left cols 0-6, right
  9-15, cols 7-8 gap, row 4 = thumb cluster.
- **Colors → Greg in Bazecor GUI.** The colormap LED→key mapping is BUGGY (see
  `led_index_BUGGY` in the decoder) — do NOT write colors programmatically.
- **Function changes → ASK FIRST.** Greg confirms manually (he flashes). Colors
  he's fine with you proposing but he applies them.

## Keycode decode (Kaleidoscope)
- Modified key = `base_HID + (flag << 8)`, flags: LCtrl=1, LAlt=2, RAlt=4,
  LShift=8, LGui=16. e.g. `Cmd+Shift+1` = (16|8)<<8 + 30 = **6174**.
- `0` = NoKey (dead, color BLACK). `65535` = Transparent (falls to lower layer,
  color RED = "return" per Greg's scheme).
- OneShotLayer = 49161+layer. OSM mods = 49153-49160. Mouse = 20480-20620
  (move 20481/2/4/8 = U/D/L/R; buttons 20545/6/8 = L/R/M; 20552/20560 = back/fwd;
  20497/8 = wheel up/down). Consumer/media ≈ 18000-24000.
- **Superkeys:** keymap code = **53980 + id** (NOT 53852). `superkeys.map` = flat
  list of 5 actions + `0` separator per superkey, then 65535 padding. Action
  slots = [tap, hold, tap&hold, 2×tap, 2×hold]. Greg can't trigger tap&hold /
  2×hold — keep those `1` (none). Codes 54108/54109 = Dygma BT-pair / Battery.

## Layers (as of 2026-06-16)
- **L0 Main** · **L1 Arrows+numpad** · **L2 Media+fn** · **L3 Mouse+win** + L4-L9 empty (leave empty — Greg won't remember more layers).
- Thumb **cluster is identical across all layers** (copied from L0). On layer N
  the OneShotLayer(N) key + transparents = red ("you're here / return").
- **L3 Mouse+win** = nav-tools layer: ruch krzyż (`@E/S/D/F`) + scroll (`@3/@C`) +
  back/fwd (`@W/@R`) left; L/R/M click (`@H/@J/@K`) right; tools `@Q`=Wooshy
  (Ctrl⌘/), `@A`=kindaVim (Ctrl[), `@?`=cheat-sheet (Ctrl⌥/).
- Mouse tuning: `mouse.speed`=1, `accelSpeed`=24, `speedLimit`=96 (tap=precise, hold=fast).

## Superkeys (current map — also in dygma-cheats descriptions)
| # | name | tap | hold | 2×tap |
|---|---|---|---|---|
| 0 | AI | Raycast (⌘Space) | AI light-rewrite (⌘G) | AI grammar (⇧⌘G) |
| 1 | Paste | paste | Raycast clipboard | 1Password search |
| 2 | Revert | undo | select-all | redo |
| 3 | Copy | copy | AI translate | — (free) |
| 4 | vs autocomplete | autocomplete | AI hard-rewrite ADHD-Slack (⌃⌘G) | read selection (⌥Esc system TTS) |
| 5 | Read reset talk | reset layers→base | — (free) | Slack channel/contact search |
| 6 | Windows | aerospace picker | sesh | tmux switch |
| 7 | leaders | tmux leader | aerospace leader | — (free) |
- Free slots to fill later: `[3]2×tap, [5]hold, [7]2×tap`.
- AI prompts (grammar/light/hard) live in Raycast AI commands; Defy just sends
  ⇧⌘G / ⌘G / ⌃⌘G. Use a cheap fast model (Haiku/4o-mini) for grammar/light.

## Colors — Mocha Neon (Greg owns these in Bazecor)
Palette (his neon, W=0): red `#FF0044` · green `#00FF66` · cyan `#00E5FF` · gold
`#FFCC00` · orange `#FF5500` · mauve `#B300FF` · blue `#0033CC` · pink `#FF00AA`.
Scheme: ESC=white · superkeys=mauve · litery=blue · symbole=cyan · modyfikatory=gold ·
Control/Space/Tab/Enter=green · DEL/X/Bksp=red · screenshot=pink · layer-buttons=orange ·
NoKey=black · Transparent(return)=red · numpad=Greg's. ⚠️ High White-channel washes
colors — keep W=0; true OFF = `0 0 0 0`.

## Workflow
1. Read the working file, decode what's relevant (use the decoder as reference).
2. For bindings: propose the change, get Greg's OK (function changes), edit
   surgically, tell Greg to import.
3. For colors: propose the scheme; Greg applies in Bazecor.
4. After substantial changes, offer to commit the layout export to dotfiles.

$ARGUMENTS
