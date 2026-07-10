#!/usr/bin/env bash
# YOLO catch-all — PreToolUse hook wired with matcher "*" (all tools).
# When the current session enabled `claude-yolo on`, auto-allow EVERY tool call
# (bypasses the interactive permission prompt). The per-tool guard hooks
# separately abstain in yolo mode, so nothing denies. No-op when yolo is off.
# See bin/claude-yolo.
set -uo pipefail

SID="${CLAUDE_CODE_SESSION_ID:-}"
DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-yolo"

if [ -n "$SID" ] && [ -f "$DIR/$SID" ]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"claude-yolo: session guard bypass active"}}\n'
fi
exit 0
