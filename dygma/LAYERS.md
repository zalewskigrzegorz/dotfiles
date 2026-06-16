# Dygma Defy — layout reference

Visual + functional reference for the current layout (`defy-layout.json`).
Generated from the live export — edit via `/dygma`. Cheat-sheet at runtime:
`dygma-cheats` (or `Ctrl+Alt+/`). Drop fresh per-layer screenshots into
`screenshots/` as `layer-main.png`, `layer-arrows.png`, `layer-media.png`, `layer-mouse.png`.

## Layers

### Layer 1 — Main

![](screenshots/layer-main.png)

```
   ESC      1      2      3      4      5      -      ∅      ∅      =      6      7      8      9      0   ⌥INS
SK:leaders      Q      W      E      R      T      [      ∅      ∅      ]      Y      U      I      O      P    DEL
SK:Windows      A      S      D      F      G SK:Read reset talk      ∅      ∅     \\      H      J      K      L      ;      '
     ⇧      Z      X      C      V      B      ∅      ∅      ∅      ∅      N      M      ,      .      /      `
 SK:AI SK:Copy    SPC SK:Paste  Llock    →L3    →L1      ⌘ SK:Revert SK:vs autocomplete    OSM #49209    OSM    SPC    →L2   BSPC
```

### Layer 2 — Arrows + numpad

![](screenshots/layer-arrows.png)

```
   ESC    C⇧C    ⇧⌘2    ⇧⌘3    ⇧⌘4    ⇧⌘5 #54109      ∅      ∅      ∅  NumLk      ∅   Num/   Num*      =      ∅
     ∅      ∅   HOME      ↑    END   PgUp #54108      ∅      ∅      ∅      ∅     N7     N8     N9   Num-    DEL
     ∅      ∅      ←      ↓      →   PgDn SK:Read reset talk      ∅      ∅      ∅      ∅     N4     N5     N6   Num+      ∅
     ⇧      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅     N1     N2     N3     N. NumEnt
 SK:AI SK:Copy    SPC SK:Paste  Llock    →L3    →L1      ⌘ SK:Revert SK:vs autocomplete    OSM #49209    OSM    SPC    →L2     N0
```

### Layer 3 — Media + fn

![](screenshots/layer-media.png)

```
     `     F1     F2     F3     F4     F5     F6      ∅      ∅     F7     F8     F9    F10    F11    F12      ∅
     ∅      ∅      ∅  media  media  media      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅
     ∅      ∅  media  media  media  media SK:Read reset talk      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅
     ⇧   C⇧F1   C⇧F2   C⇧F3    C⌥B  media      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅      ∅
 SK:AI SK:Copy    SPC SK:Paste  Llock    →L3    →L1      ⌘ SK:Revert SK:vs autocomplete    OSM #49209    OSM    SPC    →L2   BSPC
```

### Layer 4 — Mouse + win

![](screenshots/layer-mouse.png)

```
   ESC      ∅      ∅      ∅      ∅      ∅      ∅      ▽      ▽      ∅      ∅      ∅      ∅      ∅      ∅  ⇧⌘INS
     ∅    C⌘/ M-back     M↑  M-fwd      ∅      ∅      ▽      ▽ wheel↑      ∅      ∅      ∅      ∅      ∅      ∅
     ∅     C[     M←     M↓     M→      ∅ SK:Read reset talk      ▽      ▽ wheel↓ Mclk-L Mclk-M Mclk-R      ∅      ∅      ∅
     ⇧      ∅      ∅      ∅      ∅      ∅      ▽      ▽      ▽      ▽  mouse  mouse      ∅      ∅    C⌥/      ∅
 SK:AI SK:Copy    SPC SK:Paste  Llock    →L3    →L1      ⌘ SK:Revert SK:vs autocomplete    OSM #49209    OSM    SPC    →L2   BSPC
```

## Superkeys (tap / hold / 2×tap — tap&hold & 2×hold unused)
| # | Superkey | tap | hold | 2×tap |
|---|---|---|---|---|
| 0 | AI | Raycast (⌘Space) | AI light-rewrite (⌘G) | AI grammar (⇧⌘G) |
| 1 | Paste | paste (⌘V) | Raycast clipboard history | 1Password search |
| 2 | Revert | undo (⌘Z) | select-all | redo |
| 3 | Copy | copy (⌘C) | AI translate | **read clipboard aloud** (⌃⌥C) |
| 4 | vs autocomplete | autocomplete (⌃Space) | AI hard-rewrite ADHD-Slack (⌃⌘G) | — free |
| 5 | Read reset talk | reset layers → base | **read Claude aloud** (⌃⌥R) | Slack channel search |
| 6 | Windows | aerospace picker | sesh | tmux window switch |
| 7 | leaders | tmux leader | aerospace leader | — free |

## Mouse + win — nav-tools layer
- **Movement** (cross): `@E`=↑ `@S`=← `@D`=↓ `@F`=→ · **scroll** `@3`=↑ `@C`=↓ · **back/fwd** `@W`/`@R`
- **Clicks** (right hand): `@H`=L `@J`=R `@K`=M
- **Tools**: `@Q`=Wooshy (Ctrl⌘/) · `@A`=kindaVim (Ctrl[) · `@?`=cheat-sheet (Ctrl⌥/)
- Mouse tuning: speed 1, accel 24, limit 96 (tap=precise, hold=fast).

## TTS reader (ElevenLabs Monika, Flash v2.5, chunked, toggle-stop)
- **SUPER Read hold** (`Ctrl⌥R`) → reads Claude's last response (focused session).
- **Copy 2×tap** (`Ctrl⌥C`, after ⌘C) → reads the clipboard / selection.
- Long text is chunked: each press = next chunk; you only pay per chunk read.

## Colors (Mocha Neon, owned in Bazecor)
ESC=white · superkeys=mauve · letters=blue · symbols=cyan · modifiers=gold ·
Control/Space/Tab/Enter=green · DEL/X/Bksp=red · screenshot=pink · layer-buttons=orange ·
numbers=aerospace-workspace · NoKey=black · Transparent(return)=red.
