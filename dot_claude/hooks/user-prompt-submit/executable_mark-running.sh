#!/usr/bin/env bash
# UserPromptSubmit hook — Greg submitted a prompt → this agent is working.
set -u
[ "$(uname -s)" = "Darwin" ] || exit 0
INPUT=$(cat 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
[ -n "$CWD" ] || CWD="$PWD"
STATE_BIN="${CLAUDE_AGENT_STATE_BIN:-$HOME/Code/dotfiles/bin/claude-agent-state}"
[ -x "$STATE_BIN" ] && "$STATE_BIN" set running --cwd "$CWD" >/dev/null 2>&1 || true
CHIP="${CLAUDE_AGENT_CHIP:-$HOME/Code/dotfiles/bin/claude-agent-chip}"
[ -x "$CHIP" ] && ("$CHIP" >/dev/null 2>&1 &)
exit 0
