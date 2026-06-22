#!/usr/bin/env bash
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../claude-agent-badge"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export CLAUDE_AGENT_STATE_DIR="$TMP/state"; mkdir -p "$CLAUDE_AGENT_STATE_DIR"
GL=$'\U000F06A9'   # claude nerd glyph
B=$'\uf071'; W=$'\uf017'; R=$'\uf111'

printf 'state=blocked\ntarget=perm:1\n' > "$CLAUDE_AGENT_STATE_DIR/perm_1"
printf 'state=waiting\ntarget=main:2\n' > "$CLAUDE_AGENT_STATE_DIR/main_2"
printf 'state=running\ntarget=work:0\n' > "$CLAUDE_AGENT_STATE_DIR/work_0"

# Precise hook state from the file wins (3rd arg ignored when a file exists).
[ "$("$BIN" perm 1)" = " $B" ] || { echo "FAIL: blocked glyph"; exit 1; }
[ "$("$BIN" main 2)" = " $W" ] || { echo "FAIL: waiting glyph"; exit 1; }
[ "$("$BIN" work 0)" = " $R" ] || { echo "FAIL: running glyph"; exit 1; }

# No file: a claude window (name carries the glyph) falls back to ⏳.
[ "$("$BIN" cl 9 "${GL}  task")" = " $W" ] || { echo "FAIL: claude-window fallback"; exit 1; }
# No file + non-claude name → empty.
[ -z "$("$BIN" idle 5 "zsh")" ] || { echo "FAIL: non-claude should be empty"; exit 1; }
echo "PASS claude-agent-badge"
