#!/usr/bin/env bash
# SessionEnd hook — agent gone → drop its presence file.
set -u
[ "$(uname -s)" = "Darwin" ] || exit 0
STATE_BIN="${CLAUDE_AGENT_STATE_BIN:-$HOME/Code/dotfiles/bin/claude-agent-state}"
[ -x "$STATE_BIN" ] && "$STATE_BIN" clear >/dev/null 2>&1 || true
exit 0
