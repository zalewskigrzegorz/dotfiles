---
description: The Bash tool runs zsh, not bash — `=word` expands and unquoted $vars do not word-split
alwaysApply: true
---

# The Bash Tool Is zsh — Two Traps

The Bash tool runs commands in zsh. Two zsh defaults break bash-style one-liners
and cost three retries in one session (2026-09-23):

1. **A word that starts with `=` is a command lookup (`EQUALS`).**
   `echo ======` fails with `(eval):1: ===== not found`. Quote it:
   `echo "----"` or `echo '===='`. Same for any separator or argument that starts
   with `=`.
2. **An unquoted `$var` is one word, not split on spaces or newlines.**
   `files=$(git diff --name-only); oxfmt --check $files` passes the whole list as a
   single path, and the tool reports "no files found". Use `${=files}`, or pipe
   the list: `git diff --name-only | xargs pnpm exec oxfmt --check`.

When a one-liner that works in bash fails with `not found` or "no files", check
these two before you suspect the tool or the data.
