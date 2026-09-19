---
description: rm -rf on a $VAR target is denied by Greg's own guard hook by design — write the expanded literal path instead of retrying or proposing to relax the guard
alwaysApply: true
---

# `rm -rf "$VAR/…"` Is Denied — Expand the Path, Don't Fight the Guard

`dot_claude/hooks/pre-tool-use/block-dangerous-commands.sh` denies every
recursive force-delete whose target starts with `/`, `~`, `$HOME`, `../..` or
**any unexpanded shell variable**:

```
Error: Recursive force-delete on /, ~, $HOME, an unresolved $VAR, or .../.. — never allowed.
```

The hook sees the command text, not the runtime value, so `rm -rf "$SB/cfgtest"`
is indistinguishable from `rm -rf "$UNSET/cfgtest"` → `rm -rf /cfgtest`. That
is the point of the rule, and it tripped three times in one session
(2026-09-17) because each retry kept the variable.

## Rules

1. **Write the literal path.** `rm -rf /tmp/scriptc-probe/cfgtest/home_bash`,
   not `rm -rf "$SB/cfgtest/home_$label"`. If the path is built in a loop,
   `cd` into the parent first and delete relative names, or use
   `find <literal-parent> -mindepth 1 -delete`.
2. **One deny → rewrite, never retry as-is.** The guard is deterministic; the
   same text fails the same way.
3. **Never propose loosening the guard**, adding an allow pattern, or moving
   the delete into a script to dodge it. A scratch dir under `/tmp` or the
   session scratchpad is exactly where a stale variable does the most damage.
