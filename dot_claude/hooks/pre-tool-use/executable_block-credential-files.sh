#!/bin/bash
# block-credential-files — deny Bash commands that would print a credential
# store into the transcript (and, via the session hook, into MemPalace).
#
# 2026-09-27: `cat ~/.npmrc | grep -i registry` printed `_authToken=…` while
# looking for the registry URL. The token had to be rotated. This guard fires
# on any read of a known credential file and points at the safe form.
#
# Deliberately NOT bypassed by the YOLO marker: YOLO removes review gates on
# Greg's own actions, this one protects a secret from leaving the machine in a
# log, which he never asked for. Deny wins over the yolo-allow catch-all.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -n "$COMMAND" ] || exit 0

# Files whose whole point is a secret. Path fragments, matched anywhere in the command.
FILES='(~|\$HOME|/Users/[^/ ]+)/(\.npmrc|\.netrc|\.pypirc|\.git-credentials|\.config/gh/hosts\.yml|\.docker/config\.json|\.aws/credentials|\.kube/config|\.ssh/id_[a-z0-9]+)([^a-zA-Z0-9_./-]|$)|(^|[[:space:]/])\.npmrc([^a-zA-Z0-9_./-]|$)'
READERS='(^|[;&|(][[:space:]]*|[[:space:]])(cat|bat|less|more|head|tail|rg|grep|ugrep|ag|ack|sed|awk|strings|xxd|od|python3?|node|jq|yq|source|\.)[[:space:]]'

# A command that redacts on the way out (contains the `***` marker) is the sanctioned form.
if printf '%s' "$COMMAND" | grep -qE "$FILES" && printf '%s' "$COMMAND" | grep -qE "$READERS" && ! printf '%s' "$COMMAND" | grep -qF '***'; then
  reason="Reading a credential file would print its token into the transcript. Use the value-free form: \`npm config get registry\`, \`gh auth status\`, \`docker system info\`, or redact: \`sed -E 's/(_authToken=|password[=:]\s*).*/\\1***/' <file>\`."
  jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi
exit 0
