#!/usr/bin/env bash
# Stop hook — fired when Claude turn ends.
# Squash-commits all staged-by-autostage changes in ~/Code/personal/bazgroly/
# into ONE commit, then pushes to origin/master with retry-rebase fallback.
# Always exits 0 — failures only log.

set -uo pipefail

BAZGROLY="$HOME/Code/personal/bazgroly"
LOG="$HOME/.claude/bazgroly-autopush.log"

[ -d "$BAZGROLY/.git" ] || exit 0

{
  echo "---"
  echo "[$(date -Iseconds)] autopush-on-stop triggered"
  cd "$BAZGROLY" || exit 0

  git add -A 2>&1 || true

  if git diff --cached --quiet; then
    echo "nothing to commit"
    exit 0
  fi

  CHANGED=$(git diff --cached --name-only | head -5 | tr '\n' ' ')
  TS=$(date -Iseconds)
  git commit -m "auto: AI turn @ $TS" -m "Changed: $CHANGED" 2>&1 || true

  if ! git push origin master 2>&1; then
    echo "[$(date -Iseconds)] push failed, attempting pull --rebase --autostash"
    if git pull --rebase --autostash origin master 2>&1; then
      git push origin master 2>&1 || echo "[$(date -Iseconds)] push still failing after rebase"
    else
      echo "[$(date -Iseconds)] rebase conflict — manual resolve required in $BAZGROLY"
    fi
  fi
} >>"$LOG" 2>&1

exit 0
