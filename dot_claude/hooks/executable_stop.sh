#!/usr/bin/env bash
# ~/.claude/hooks/stop.sh
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

# 2) Optional Tine TTS push (opt-in via env)
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
