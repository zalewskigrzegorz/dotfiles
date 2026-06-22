#!/usr/bin/env bash
# claude-agent-state: set (running/waiting/blocked) + list with claude-window
# fallback, using shimmed tmux + ps.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../claude-agent-state"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export CLAUDE_AGENT_STATE_DIR="$TMP/state"
export PATH="$TMP/shim:$PATH"; mkdir -p "$TMP/shim"
GL=$'\U000F06A9'   # claude nerd glyph (marks a claude window)

# Shim tmux. list-panes maps our PID chain to 'main:2'. list-windows: the
# name-bearing form (fallback) lists claude windows main:2 + cl:3 and a plain
# window other:0; the bare form (GC + live set) lists the targets.
cat >"$TMP/shim/tmux" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *list-panes*) echo "$$ main:2" ;;
  *window_name*) printf 'main:2\t${GL}  claude\nother:0\tzsh\ncl:3\t${GL}  task\n' ;;
  *list-windows*) printf 'main:2\nother:0\ncl:3\n' ;;
esac
EOF
chmod +x "$TMP/shim/tmux"
export TMUX_BIN="$TMP/shim/tmux"

# Case 1: set waiting writes a file tagged waiting with our resolved target.
"$BIN" set waiting --cwd "$TMP"
f=$(ls "$CLAUDE_AGENT_STATE_DIR")
grep -q '^state=waiting' "$CLAUDE_AGENT_STATE_DIR/$f" || { echo "FAIL[1]: not waiting"; exit 1; }
grep -q '^target=main:2' "$CLAUDE_AGENT_STATE_DIR/$f" || { echo "FAIL[1]: wrong target"; exit 1; }

# Case 2: blocked is a valid state and overwrites (no dup file).
"$BIN" set blocked --cwd "$TMP"
[ "$(ls "$CLAUDE_AGENT_STATE_DIR" | wc -l | tr -d ' ')" = "1" ] || { echo "FAIL[2]: dup file"; exit 1; }
grep -q '^state=blocked' "$CLAUDE_AGENT_STATE_DIR/$f" || { echo "FAIL[2]: not blocked"; exit 1; }

# Case 3: list emits the precise file state for main:2 (blocked).
"$BIN" list | grep -q $'^blocked\tmain:2\t' || { echo "FAIL[3]: main:2 not blocked"; "$BIN" list; exit 1; }

# Case 4: FALLBACK — cl:3 is a claude window (glyph) with no file → waiting.
"$BIN" list | grep -q $'^waiting\tcl:3\t' || { echo "FAIL[4]: cl:3 fallback missing"; "$BIN" list; exit 1; }

# Case 5: non-claude window other:0 (no glyph, no file) is NOT listed.
"$BIN" list | grep -q 'other:0' && { echo "FAIL[5]: non-claude window leaked"; exit 1; }

# Case 6: GC prunes a file whose target is not a live window.
echo $'state=waiting\ntarget=dead:9' > "$CLAUDE_AGENT_STATE_DIR/dead_9"
"$BIN" list >/dev/null
[ -f "$CLAUDE_AGENT_STATE_DIR/dead_9" ] && { echo "FAIL[6]: stale file not GC'd"; exit 1; }

# Case 7: clear removes our target's file.
"$BIN" clear
[ -f "$CLAUDE_AGENT_STATE_DIR/$f" ] && { echo "FAIL[7]: clear left file"; exit 1; }

echo "PASS claude-agent-state"
