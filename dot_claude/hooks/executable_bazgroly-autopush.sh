#!/usr/bin/env bash
# Auto-commits and pushes any Write/Edit inside ~/Code/personal/bazgroly/
# to origin/master. PostToolUse hook for Edit|Write operations.
# Always exits 0 — failures only log, never block follow-up tools.

set -uo pipefail

BAZGROLY="$HOME/Code/personal/bazgroly"
LOG="$HOME/.claude/bazgroly-autopush.log"

if ! command -v jq >/dev/null 2>&1; then
  echo "[$(date -Iseconds)] jq missing — skipping" >>"$LOG"
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -z "$FILE_PATH" ] && exit 0

case "$FILE_PATH" in
  "$BAZGROLY"/*) ;;
  *) exit 0 ;;
esac

[ -d "$BAZGROLY/.git" ] || { echo "[$(date -Iseconds)] $BAZGROLY is not a git repo" >>"$LOG"; exit 0; }

REL="${FILE_PATH#$BAZGROLY/}"

{
  echo "---"
  echo "[$(date -Iseconds)] autopush triggered for $REL"
  cd "$BAZGROLY" || exit 0

  if ! git diff --quiet -- "$REL" 2>/dev/null || ! git ls-files --error-unmatch -- "$REL" >/dev/null 2>&1; then
    git add -- "$REL" 2>&1 || true
    if ! git diff --cached --quiet; then
      git commit -m "chore: update $REL 📝" 2>&1 || true
      git push origin master 2>&1 || true
    else
      echo "nothing to commit after add"
    fi
  else
    echo "no changes detected for $REL"
  fi
} >>"$LOG" 2>&1

exit 0
