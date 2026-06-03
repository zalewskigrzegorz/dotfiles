#!/usr/bin/env bash
# ~/.claude/hooks/bazgroly.sh
# Unified entrypoint for bazgroly autopush hooks.
# Subcommands:
#   autostage       PostToolUse Edit|Write — git-add file under bazgroly tree
#   push-on-start   SessionStart           — push any commits ahead of upstream
#   push-on-stop    Stop                   — squash-commit staged + push w/ rebase fallback
#
# Always exits 0 — failures only log, never block follow-up tools.

set -uo pipefail

BAZGROLY="$HOME/Code/personal/bazgroly"
LOG="$HOME/.claude/bazgroly-autopush.log"

repo_ok() { [ -d "$BAZGROLY/.git" ]; }

autostage() {
  command -v jq >/dev/null 2>&1 || { echo "[$(date -Iseconds)] jq missing — skipping" >>"$LOG"; exit 0; }

  local input file_path rel
  input=$(cat)
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
  [ -z "$file_path" ] && exit 0

  case "$file_path" in
    "$BAZGROLY"/*) ;;
    *) exit 0 ;;
  esac

  repo_ok || { echo "[$(date -Iseconds)] $BAZGROLY is not a git repo" >>"$LOG"; exit 0; }

  rel="${file_path#$BAZGROLY/}"
  {
    echo "---"
    echo "[$(date -Iseconds)] autostage triggered for $rel"
    cd "$BAZGROLY" || exit 0
    git add -- "$rel" 2>&1 || true
  } >>"$LOG" 2>&1
}

push_on_start() {
  repo_ok || exit 0
  {
    cd "$BAZGROLY" || exit 0
    if git rev-parse --verify HEAD >/dev/null 2>&1; then
      local ahead
      ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
      if [ "$ahead" -gt 0 ]; then
        echo "[$(date -Iseconds)] SessionStart catch-up: $ahead commits ahead, pushing"
        git push origin master 2>&1 || echo "[$(date -Iseconds)] catch-up push failed (continuing)"
      fi
    fi
  } >>"$LOG" 2>&1
}

push_on_stop() {
  repo_ok || exit 0
  {
    echo "---"
    echo "[$(date -Iseconds)] autopush-on-stop triggered"
    cd "$BAZGROLY" || exit 0

    git add -A 2>&1 || true

    if git diff --cached --quiet; then
      echo "nothing to commit"
      exit 0
    fi

    local changed ts
    changed=$(git diff --cached --name-only | head -5 | tr '\n' ' ')
    ts=$(date -Iseconds)
    git commit -m "auto: AI turn @ $ts" -m "Changed: $changed" 2>&1 || true

    if ! git push origin master 2>&1; then
      echo "[$(date -Iseconds)] push failed, attempting pull --rebase --autostash"
      if git pull --rebase --autostash origin master 2>&1; then
        git push origin master 2>&1 || echo "[$(date -Iseconds)] push still failing after rebase"
      else
        echo "[$(date -Iseconds)] rebase conflict — manual resolve required in $BAZGROLY"
      fi
    fi
  } >>"$LOG" 2>&1
}

case "${1:-}" in
  autostage)     autostage ;;
  push-on-start) push_on_start ;;
  push-on-stop)  push_on_stop ;;
  *)
    echo "usage: $0 {autostage|push-on-start|push-on-stop}" >&2
    exit 2
    ;;
esac

exit 0
