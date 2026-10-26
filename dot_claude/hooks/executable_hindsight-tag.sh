#!/usr/bin/env bash
# ~/.claude/hooks/hindsight-tag.sh
# PreToolUse on mcp__hindsight__retain / sync_retain.
# Auto-injects metadata.project from git root basename, PWD basename, or "_global".
#
# Reads PreToolUse JSON on stdin, prints hookSpecificOutput.updatedInput on stdout.
# If modification fails or wrong tool, prints nothing (input runs untouched).
# Always exits 0.

set -uo pipefail

LOG="$HOME/.claude/hindsight-tag.log"

# Ensure jq exists; otherwise pass-through.
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

case "$tool_name" in
  mcp__hindsight__retain|mcp__hindsight__sync_retain) ;;
  *) exit 0 ;;
esac

# Resolve project tag: main repo basename (shared by all its worktrees) → PWD basename → _global.
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"
project=""
common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
[ -n "$common" ] && project=$(basename "$(dirname "$common")")
[ -z "$project" ] && project=$(basename "$cwd" 2>/dev/null)
[ -z "$project" ] && project="_global"

# Inject metadata.project if not already set. Claude Code applies only
# hookSpecificOutput.updatedInput; echoing the input back changed nothing.
# "allow" is neutral here: mcp__hindsight__* is already in permissions.allow.
modified=$(printf '%s' "$input" | jq -c --arg p "$project" '
  {hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    updatedInput: (.tool_input | .metadata = ((.metadata // {}) | (.project //= $p)))
  }}
' 2>/dev/null)

if [ -z "$modified" ]; then
  echo "[$(date -Iseconds)] jq mutation failed; pass-through" >>"$LOG" 2>&1
  exit 0
fi

echo "[$(date -Iseconds)] tagged $tool_name → project=$project" >>"$LOG" 2>&1
printf '%s' "$modified"
