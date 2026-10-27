---
description: On Greg's Mac `grep` is ugrep, which is stricter about regex than GNU grep. BRE quantifier escapes like `\+`, `\?`, `\{` are interpreted as ERE operators and error out. Rules for writing grep patterns that work here.
alwaysApply: true
---

# `grep` is ugrep — Write Patterns That Don't Blow Up

On Greg's Mac, `grep` resolves to **ugrep**, not GNU/BSD grep. ugrep is
stricter: a leading or operand-less quantifier is a hard error, not a literal.

ugrep reads BRE `\+ \? \{ \|` as ERE operators and errors out (`invalid syntax`,
`error at position N`). Use `grep -E` with explicit escapes, `-F` for a fixed
string, or `rg`. The lab (Debian) has GNU grep; patterns written this way work on both.

**The lab has no `rg`:** inside `ssh mrglaszki '…'` or
`docker exec` on the lab, `rg` fails with `rg: command not found` (2026-09-29).
Use `grep -E` / `grep -F` there.

**The `guard` mod denies, with the fix in the deny:** BRE escapes in `grep`,
`rg -E`, `rg --type tsx`, `2>/dev/null` on `rg`, flags after `--`, `\1` without
`--pcre2`.

**`rg` skips gitignored dirs, `node_modules` included.** An empty search there
means "ignored", not "rtk hid it": `rg --no-ignore -l '<term>'
"$(realpath apps/<app>/node_modules/<pkg>)" -g '*.d.ts'`, with the empty-variable
guard. Four empty searches came before that on 2026-10-13 (aaee25fc).
