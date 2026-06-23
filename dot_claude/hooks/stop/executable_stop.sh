#!/usr/bin/env bash
# ~/.claude/hooks/stop/stop.sh
# Claude Code Stop hook — fired when assistant turn ends.
# Cheap, non-blocking. Two layers:
#   1) OSC 9 terminal notification (works through SSH on Ghostty/iTerm)
#   2) Optional cross-machine TTS via Tine (opt-in via CLAUDE_TINE_NOTIFY=1)
set -u

# 1) OSC 9 — terminal-native "finished" marker for SSH / Linux terminals.
# The "Claude is waiting" desktop notification now lives in the Notification
# hook (notify-waiting.sh → alerter); Stop = turn finished, not "waiting", and
# the sound moved there too. Silently no-ops in hook-subprocess context (no /dev/tty).
printf '\033]9;Claude finished\007' > /dev/tty 2>/dev/null || true

# Mark this agent waiting (turn finished → ball in user's court).
STATE_BIN="${CLAUDE_AGENT_STATE_BIN:-$HOME/Code/dotfiles/bin/claude-agent-state}"
[ -x "$STATE_BIN" ] && "$STATE_BIN" set waiting --cwd "${PWD:-$HOME}" >/dev/null 2>&1 || true
CHIP="${CLAUDE_AGENT_CHIP:-$HOME/Code/dotfiles/bin/claude-agent-chip}"
[ -x "$CHIP" ] && ("$CHIP" >/dev/null 2>&1 &)

# 2) Sound layer — status-dependent.
# Finished if clean, error if last tool failed. Always append subagent-done at end.
if [ -f "$HOME/.claude/hooks/sounds/.error" ]; then
  # Error state — play error sound instead of finished
  sound="$HOME/.claude/hooks/sounds/claude-error.mp3"
  rm -f "$HOME/.claude/hooks/sounds/.error" # clean marker
else
  # Success — play finished sound
  sound="$HOME/.claude/hooks/sounds/claude-finished.mp3"
fi
[ -f "$sound" ] && (afplay "$sound" >/dev/null 2>&1 &)

# Subagent-done sound (delayed slightly so it doesn't overlap with main sound)
(sleep 1; [ -f "$HOME/.claude/hooks/sounds/claude-subagent-done.mp3" ] && afplay "$HOME/.claude/hooks/sounds/claude-subagent-done.mp3" >/dev/null 2>&1 &) &

# 3) Optional Tine TTS push (opt-in via env)
if [ "${CLAUDE_TINE_NOTIFY:-0}" = "1" ]; then
  if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    endpoint="${TINE_ENDPOINT:-http://lab:8080/say}"
    project="$(basename "${PWD:-unknown}")"
    msg="Claude finished in ${project}"
    curl -fsS -m 2 -X POST "$endpoint" \
      -H 'content-type: application/json' \
      -d "$(jq -n --arg text "$msg" --arg voice "office" '{text: $text, voice: $voice}')" \
      > /dev/null 2>&1 || true
  fi
fi

exit 0
