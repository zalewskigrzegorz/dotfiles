#!/bin/bash
# secrets-cleanup — SessionEnd: remove the session's <scratchpad>/secrets/ that
# `secret-in` filled (ops-traps.md, "A secret goes in through Greg"), so a
# one-off password does not outlive the session that asked for it.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
sid=$(jq -r '.session_id // empty' 2>/dev/null || true)
[[ "$sid" =~ ^[A-Za-z0-9-]+$ ]] || exit 0
root="/private/tmp/claude-$(id -u)"
[ -d "$root" ] || exit 0
find "$root" -mindepth 4 -maxdepth 4 -type d -path "*/$sid/scratchpad/secrets" -print0 |
  while IFS= read -r -d '' dir; do
    find "$dir" -mindepth 1 -delete && rmdir "$dir"
  done
exit 0
