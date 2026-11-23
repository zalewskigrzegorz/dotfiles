---
description: On Greg's Mac `grep` is ugrep, which is stricter about regex than GNU grep. BRE quantifier escapes like `\+`, `\?`, `\{` are interpreted as ERE operators and error out. Rules for writing grep patterns that work here.
alwaysApply: true
---

# `grep` is ugrep, `rg` has its own traps

- On the Mac `grep` is **ugrep**: BRE `\+ \? \{ \|` are ERE operators or errors (`invalid syntax`). Use `grep -E` with explicit escapes, `-F` for a fixed string, or `rg`; this also works on the lab's GNU grep.
- **The lab has no `rg`** (inside `ssh mrglaszki '…'` or `docker exec` there): `grep -E` / `grep -F`.
- Guard denies, with the fix: BRE escapes in `grep`, `rg -E`, `rg --type tsx`, `2>/dev/null` on `rg`, flags after `--`, `\1` without `--pcre2`.
- **`rg` skips gitignored dirs, `node_modules` included**: an empty search there means "ignored", not "rtk hid it". `rg --no-ignore -l '<term>' "$(realpath apps/<app>/node_modules/<pkg>)" -g '*.d.ts'`, with the empty-variable guard (ops-traps).
