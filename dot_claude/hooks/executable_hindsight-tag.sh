#!/usr/bin/env bash
# ~/.claude/hooks/hindsight-tag.sh
# PreToolUse on mcp__hindsight__retain / sync_retain.
# Auto-injects metadata.project from git root basename, PWD basename, or "_global".
#
# Reads PreToolUse JSON on stdin, prints (possibly modified) JSON on stdout.
# If modification fails or wrong tool, passes input through untouched.
# Always exits 0.

set -uo pipefail

LOG="$HOME/.claude/hindsight-tag.log"

# Ensure jq exists; otherwise pass-through.
command -v jq >/dev/null 2>&1 || { cat; exit 0; }

input=$(cat)
tool_name=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)

case "$tool_name" in
  mcp__hindsight__retain|mcp__hindsight__sync_retain) ;;
  *)
    printf '%s' "$input"
    exit 0
    ;;
esac

# Resolve project tag: git root basename → PWD basename → _global.
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$cwd" ] && cwd="$PWD"
project=$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null | xargs -I{} basename {} 2>/dev/null)
[ -z "$project" ] && project=$(basename "$cwd" 2>/dev/null)
[ -z "$project" ] && project="_global"

# Inject metadata.project if not already set.
modified=$(printf '%s' "$input" | jq --arg p "$project" '
  .tool_input.metadata = ((.tool_input.metadata // {}) | (.project //= $p))
' 2>/dev/null)

if [ -z "$modified" ]; then
  echo "[$(date -Iseconds)] jq mutation failed; pass-through" >>"$LOG" 2>&1
  printf '%s' "$input"
  exit 0
fi

echo "[$(date -Iseconds)] tagged $tool_name → project=$project" >>"$LOG" 2>&1
printf '%s' "$modified"
