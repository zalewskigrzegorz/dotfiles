#!/usr/bin/env bash
# Auto-mode catch-all — PreToolUse hook wired with matcher "*" (all tools).
# "acceptEdits/auto = YOLO z pasami" (2026-07-31, spec: bazgroly/dotfiles/specs/
# 2026-07-31-permissions-auto-yolo-design.md):
#
# When the session runs in an interactive auto mode (acceptEdits or auto),
# emit "allow" for every tool call so nothing prompts — compound Bash commands,
# edits outside ~/Code, MCP calls, anything the settings allowlist misses.
#
# The seatbelts stay on: guard hooks (block-dangerous-commands, mcp-guard,
# protect-files) run on the same PreToolUse event and their "deny"/"ask"
# decisions take precedence over this hook's "allow", so the suicidal list
# still hard-blocks and the one-click confirmations still pop.
#
# No-op in default/plan (normal prompting) and in dontAsk/bypassPermissions
# (those modes already skip prompts; guards handle their own deny there).
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
PERMISSION_MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // ""' 2>/dev/null || echo "")

case "$PERMISSION_MODE" in
  acceptEdits|auto)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"auto-allow: interactive auto mode (%s)"}}\n' "$PERMISSION_MODE"
    ;;
esac
exit 0
