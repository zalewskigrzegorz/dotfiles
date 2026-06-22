#!/usr/bin/env bash
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../claude-agent-badge"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export CLAUDE_AGENT_STATE_DIR="$TMP/state"; mkdir -p "$CLAUDE_AGENT_STATE_DIR"

printf 'state=waiting\ntarget=main:2\n' > "$CLAUDE_AGENT_STATE_DIR/main_2"
printf 'state=running\ntarget=work:0\n' > "$CLAUDE_AGENT_STATE_DIR/work_0"

[ "$("$BIN" main 2)" = " ⏳" ] || { echo "FAIL: waiting glyph"; exit 1; }
[ "$("$BIN" work 0)" = " ●" ] || { echo "FAIL: running glyph"; exit 1; }
[ -z "$("$BIN" idle 5)" ] || { echo "FAIL: idle should be empty"; exit 1; }
echo "PASS claude-agent-badge"
