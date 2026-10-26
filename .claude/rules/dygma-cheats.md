---
paths:
  - "bin/dygma-cheats"
---

# `bin/dygma-cheats`

Two sessions edited it at once; one rewrite dropped `newest_export`,
`WOOSHY_ACTIONS` and `CLAUDE_ACTIONS`, a `bin/sync` copied the half-done file
to `~/bin` and the picker died on `NameError` (56251e09).

- Before editing or `bin/sync`: `git diff bin/dygma-cheats`. Lines you did not
  write → tell that session first (`ListAgents` → `SendMessage`).
- After editing: `bin/dygma-cheats --list` still prints every group (hyprmac,
  Wooshy, Vimma, Claude).
- A new tool = a `<NAME>_ACTIONS` list plus an `entries += …` line in
  `build_entries`.
- No `bin/sync` on a half-finished file: stage 28 rsyncs all of `bin/`.
- A chord on a punctuation key (`; ' , . [ ] \`) added in `bin/hyprmac-config`
  → `bin/dygma-cheats --list | rg '<chord>'`. No row means a keycode missing
  from the script's map, not a missing chord (9 chords were silently dropped
  until `a31cda2`, 673e7d5e).
