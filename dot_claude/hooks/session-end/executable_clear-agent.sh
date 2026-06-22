#!/usr/bin/env bash
# SessionEnd hook — agent gone → drop its presence file.
set -u
[ "$(uname -s)" = "Darwin" ] || exit 0
STATE_BIN="${CLAUDE_AGENT_STATE_BIN:-$HOME/Code/dotfiles/bin/claude-agent-state}"
[ -x "$STATE_BIN" ] && "$STATE_BIN" clear >/dev/null 2>&1 || true
CHIP="${CLAUDE_AGENT_CHIP:-$HOME/Code/dotfiles/bin/claude-agent-chip}"
[ -x "$CHIP" ] && ("$CHIP" >/dev/null 2>&1 &)
exit 0
