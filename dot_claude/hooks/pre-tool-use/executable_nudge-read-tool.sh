#!/bin/bash
# nudge-read-tool — a bare `cat|head|tail <one file>` gets a one-line reminder
# that Read (offset/limit) is the tool for that. Never blocks and sets no
# permission decision: the rule existed and was still broken 58 times in one
# session (retro 2026-10-02, b0af38dc), so it wants a nudge at the moment, not
# another paragraph. Pipes, redirects, chains, globs and `tail -f` pass silently.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
printf '%s' "$COMMAND" | grep -qE '^[[:space:]]*(cat|head|tail)([[:space:]]+-[a-zA-Z0-9]+([[:space:]]*[0-9]+)?)*[[:space:]]+[^][:space:]|;&<>()$`*?{}[]+[[:space:]]*$' || exit 0
printf '%s' "$COMMAND" | grep -qE '^[[:space:]]*tail[[:space:]].*-[a-zA-Z]*[fF]' && exit 0
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:"A plain cat/head/tail of one file: use the Read tool next time (offset/limit for a range). It shows line numbers and skips the rtk filter. Not blocked."}}'
exit 0
