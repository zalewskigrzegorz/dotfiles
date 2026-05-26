#!/usr/bin/env bash
# SessionStart hook — catch-up push for any local commits made by
# non-Claude clients (vim, Cursor, manual edits) since last Stop.
# Idempotent: silent if nothing to push.

set -uo pipefail

BAZGROLY="$HOME/Code/personal/bazgroly"
LOG="$HOME/.claude/bazgroly-autopush.log"

[ -d "$BAZGROLY/.git" ] || exit 0

{
  cd "$BAZGROLY" || exit 0
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
    if [ "$AHEAD" -gt 0 ]; then
      echo "[$(date -Iseconds)] SessionStart catch-up: $AHEAD commits ahead, pushing"
      git push origin master 2>&1 || echo "[$(date -Iseconds)] catch-up push failed (continuing)"
    fi
  fi
} >>"$LOG" 2>&1

exit 0
