---
description: On Greg's Mac `grep` is ugrep, which is stricter about regex than GNU grep. BRE quantifier escapes like `\+`, `\?`, `\{` are interpreted as ERE operators and error out. Rules for writing grep patterns that work here.
alwaysApply: true
---

# `grep` is ugrep — Write Patterns That Don't Blow Up

On Greg's Mac, `grep` resolves to **ugrep**, not GNU/BSD grep. ugrep is
stricter: a leading or operand-less quantifier is a hard error, not a literal.

## The failure you already hit

```bash
git diff ... | grep -v '^\+\+\+'
# ugrep: error at position 5  (?m)^+++  \___invalid syntax
```

ugrep reads `\+` as the ERE quantifier `+` (repeat previous), so `^+` has
nothing to repeat → `invalid syntax`. GNU grep would treat `\+` as a literal
plus and pass. Same trap for `\?`, `\{n,m\}`, `\|` in default mode.

## Rules

1. **To match a literal `+ ? { | ( )`, use `-E` and backslash-escape them, or
   `-F` for a fixed string.** Don't rely on BRE `\+` meaning "literal plus".
   - Literal `+++`: `grep -E '^\+\+\+'` or `grep -F '+++'`.
   - Diff added lines only: `grep -E '^\+[^+]'` (a `+` not followed by `+`).
2. **`-F` (fixed strings) is the safe default** when the pattern is a plain
   string with no regex intent — no escaping headaches at all.
3. **Prefer `rg` (ripgrep) for anything non-trivial.** It's installed, its
   Rust regex is predictable, and Serena/`rg` are already the house tools for
   code search. Reach for `grep` only for quick inline pipe filters.
4. **If a grep errors with `invalid syntax` / `error at position N`**, that's
   ugrep rejecting a GNU-ism — rewrite with `-E` + explicit escapes or switch
   to `-F` / `rg`. Don't assume the file or the data is the problem.

macOS only — the lab (Debian) has GNU grep, where `\+` works the old way.
Patterns written to the rules above are portable to both.
