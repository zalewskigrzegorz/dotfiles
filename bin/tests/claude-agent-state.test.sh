#!/usr/bin/env bash
# claude-agent-state: set/clear/list contract with shimmed tmux + ps.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../claude-agent-state"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export CLAUDE_AGENT_STATE_DIR="$TMP/state"
export PATH="$TMP/shim:$PATH"; mkdir -p "$TMP/shim"

# Shim tmux: list-panes maps our PPID chain to sess:win 'main:2';
# list-windows enumerates live targets for GC.
cat >"$TMP/shim/tmux" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *"list-panes"*) echo "$$ main:2" ;;
  *"list-windows"*) echo "main:2"; echo "other:0" ;;
esac
EOF
chmod +x "$TMP/shim/tmux"
export TMUX_BIN="$TMP/shim/tmux"

# Case 1: set waiting writes a file tagged waiting with our target.
"$BIN" set waiting --cwd "$TMP"
f=$(ls "$CLAUDE_AGENT_STATE_DIR")
grep -q '^state=waiting' "$CLAUDE_AGENT_STATE_DIR/$f" || { echo "FAIL[1]: not waiting"; exit 1; }
grep -q '^target=main:2' "$CLAUDE_AGENT_STATE_DIR/$f" || { echo "FAIL[1]: wrong target"; exit 1; }

# Case 2: set running overwrites state for same target (no dup file).
"$BIN" set running --cwd "$TMP"
[ "$(ls "$CLAUDE_AGENT_STATE_DIR" | wc -l | tr -d ' ')" = "1" ] || { echo "FAIL[2]: dup file"; exit 1; }
grep -q '^state=running' "$CLAUDE_AGENT_STATE_DIR/$f" || { echo "FAIL[2]: not running"; exit 1; }

# Case 3: list emits STATE<TAB>TARGET<TAB>LABEL.
out=$("$BIN" list)
printf '%s' "$out" | grep -q $'^running\tmain:2\t' || { echo "FAIL[3]: list shape: $out"; exit 1; }

# Case 4: --waiting filters out running.
[ -z "$("$BIN" list --waiting)" ] || { echo "FAIL[4]: running leaked into --waiting"; exit 1; }

# Case 5: GC prunes a file whose target is not in tmux list-windows.
echo $'state=waiting\ntarget=dead:9' > "$CLAUDE_AGENT_STATE_DIR/dead_9"
"$BIN" list >/dev/null
[ -f "$CLAUDE_AGENT_STATE_DIR/dead_9" ] && { echo "FAIL[5]: stale file not GC'd"; exit 1; }

# Case 6: clear removes our target's file.
"$BIN" clear
[ -z "$(ls "$CLAUDE_AGENT_STATE_DIR" 2>/dev/null)" ] || { echo "FAIL[6]: clear left files"; exit 1; }

echo "PASS claude-agent-state"
