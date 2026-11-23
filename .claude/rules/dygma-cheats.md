---
paths:
  - "bin/dygma-cheats"
---

# `bin/dygma-cheats`

Two sessions once edited it at once; a half-done file reached `~/bin` via
`bin/sync` and the picker died on `NameError` (56251e09).

- Before editing or `bin/sync`: `git diff bin/dygma-cheats`. Lines you did not
  write → tell that session first (`ListAgents` → `SendMessage`).
- After editing: `bin/dygma-cheats --list` still prints every group (hyprmac,
  Wooshy, Vimma, Claude).
- A new tool = a `<NAME>_ACTIONS` list plus an `entries += …` line in
  `build_entries`.
- No `bin/sync` on a half-finished file: stage 28 rsyncs all of `bin/`.
- A chord on a punctuation key (`; ' , . [ ] \`) added in `bin/hyprmac-config`
  → `bin/dygma-cheats --list | rg '<chord>'`. No row means a keycode missing
  from the script's map, not a missing chord (fixed for 9 chords in `2577839`).
