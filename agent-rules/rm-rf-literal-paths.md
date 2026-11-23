---
description: rm -rf on a $VAR target is denied by Greg's own guard hook by design — write the expanded literal path instead of retrying or proposing to relax the guard
alwaysApply: true
---

# `rm -rf "$VAR/…"` Is Denied: Expand the Path

`block-dangerous-commands.sh` denies every recursive force-delete whose target starts with `/`, `~`, `$HOME`, `../..` or **any unexpanded shell variable**: it sees the text, not the value, and `$UNSET/x` is `/x`.

1. **Write the literal path** (`rm -rf /tmp/scriptc-probe/cfgtest/home_bash`). A path built in a loop: `cd` into the parent and delete relative names, or `find <literal-parent> -mindepth 1 -delete`.
2. **One deny → rewrite**, never retry the same text.
3. **Never propose loosening the guard**, an allow pattern, or moving the delete into a script to dodge it.
