#!/usr/bin/env bash
# ~/.claude/hooks/stop.sh
# Claude Code Stop hook — fired when assistant turn ends.
# Cheap, non-blocking. Four layers:
#   1) OSC 9 terminal notification (works through SSH on Ghostty/iTerm)
#   2) Invalidate claude-sessions cache so next read is fresh
#   3) macOS only: trigger sketchybar widget for instant refresh
#   4) Optional cross-machine TTS via Tine (opt-in via CLAUDE_TINE_NOTIFY=1)
set -u

# 1a) macOS-native notification (primary path on Darwin).
# osascript works without a controlling TTY — important because Claude Code
# hooks run in a subprocess without /dev/tty, which makes OSC 9 silently fail.
# Sound is played via afplay separately so we can use a custom cyberpunk-vibe
# mp3 (osascript's `sound name "X"` only supports built-in macOS aiff sounds).
if [ "$(uname -s)" = "Darwin" ]; then
  osascript -e 'display notification "Claude is waiting" with title "Claude"' >/dev/null 2>&1 || true
  # Background-play the custom notification sound; never block hook exit.
  sound_file="$HOME/.claude/hooks/sounds/claude-done.mp3"
  [ -f "$sound_file" ] && (afplay "$sound_file" >/dev/null 2>&1 &)
fi

# 1b) OSC 9 — fallback for SSH / Linux terminals (survives ssh tunnels).
# Silently no-ops in hook-subprocess context (no /dev/tty) but lights up
# when the script is run interactively from a terminal.
printf '\033]9;Claude is waiting\007' > /dev/tty 2>/dev/null || true

# 2) Invalidate claude-sessions cache (fswatch may not catch the .jsonl mtime in time)
rm -f "/tmp/claude-sessions-${UID:-$(id -u)}.json" 2>/dev/null || true

# 3) macOS sketchybar trigger (skipped on lab/Linux)
if [ "$(uname -s)" = "Darwin" ] && command -v sketchybar >/dev/null 2>&1; then
  sketchybar --trigger claude_sessions_changed 2>/dev/null || true
fi

# 4) Optional Tine TTS push (opt-in via env)
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
