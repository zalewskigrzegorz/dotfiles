#!/usr/bin/env bash
# Notification hook — fires whenever Claude Code emits a Notification (permission
# prompt, idle prompt, elicitation dialog, ...). Marks this agent `waiting` in the
# shared state dir (read by the tmux badge, pickers, sketchybar chip) and plays
# claude-waiting.mp3. macOS-only; never blocks. Logs raw payload to
# ~/.claude/notify-waiting.log for diagnosing future schema changes.
set -u

command -v jq >/dev/null 2>&1 || exit 0
[ "$(uname -s)" = "Darwin" ] || exit 0

INPUT=$(cat)

# Debug log — Claude Code's Notification payload is undocumented; keep a tail
# to inspect what actually arrives. Truncate to avoid runaway growth.
LOG="$HOME/.claude/notify-waiting.log"
{
  echo "---"
  echo "[$(date -Iseconds)] notification hook fired"
  printf '%s\n' "$INPUT"
} >>"$LOG" 2>&1 || true
# Keep last 500 lines only (cheap, ignore errors)
if [ -f "$LOG" ] && command -v tail >/dev/null 2>&1; then
  tail -n 500 "$LOG" >"$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null || true
fi

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"

# ── Mark this agent waiting (ball in user's court) ──────────────────────────
STATE_BIN="${CLAUDE_AGENT_STATE_BIN:-$HOME/Code/dotfiles/bin/claude-agent-state}"
[ -x "$STATE_BIN" ] && "$STATE_BIN" set waiting --cwd "$CWD" >/dev/null 2>&1 || true

# ── Sound ─────────────────────────────────────────────────────────────────
sound="$HOME/.claude/hooks/sounds/claude-waiting.mp3"
[ -f "$sound" ] && (afplay "$sound" >/dev/null 2>&1 &)

exit 0
