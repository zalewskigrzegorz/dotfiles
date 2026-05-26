#!/usr/bin/env bash
# Auto-stages any Write/Edit inside ~/Code/personal/bazgroly/ for later
# commit in the Stop hook (bazgroly-autopush-on-stop.sh). PostToolUse hook
# for Edit|Write operations.
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
  echo "[$(date -Iseconds)] autostage triggered for $REL"
  cd "$BAZGROLY" || exit 0
  git add -- "$REL" 2>&1 || true
} >>"$LOG" 2>&1

exit 0
