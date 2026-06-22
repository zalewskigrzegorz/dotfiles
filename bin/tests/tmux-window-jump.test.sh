#!/usr/bin/env bash
# tmux-window-jump (agent action-jumper): candidates = blocked/waiting claude
# windows, current excluded, blocked sorted first, jump by IDs + explicit client.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../tmux-window-jump"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/shim"; export REC="$TMP/rec"; : >"$REC"

# tmux shim: current window = cur:0; list-windows yields ids for perm/work/cur.
cat >"$TMP/shim/tmux" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *display-message*) echo "cur:0" ;;
  *list-clients*) echo "tty0" ;;
  *list-windows*) printf '$1\t@1\tperm:1\tperm  ·  1 claude\n$2\t@2\twork:2\twork  ·  2 claude\n$0\t@0\tcur:0\tcur  ·  0 claude\n' ;;
  *) echo "tmux $*" >> "$REC" ;;
esac
EOF
# state: perm:1 blocked, work:2 waiting, cur:0 waiting (current → excluded).
cat >"$TMP/shim/claude-agent-state" <<'EOF'
#!/usr/bin/env bash
printf 'blocked\tperm:1\t/x\nwaiting\twork:2\t/y\nwaiting\tcur:0\t/z\n'
EOF
cat >"$TMP/shim/choose" <<EOF
#!/usr/bin/env bash
cat > "$TMP/choose-in"
echo 0
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/shim/claude-focus-session"
chmod +x "$TMP/shim/"*
export CLAUDE_AGENT_STATE_BIN="$TMP/shim/claude-agent-state"
export CLAUDE_FOCUS_BIN="$TMP/shim/claude-focus-session"
export TMUX_BIN="$TMP/shim/tmux"
export CHOOSE_BIN="$TMP/shim/choose"

"$BIN"

# Two candidates → picker shown.
[ -f "$TMP/choose-in" ] || { echo "FAIL: picker not shown for 2 candidates"; exit 1; }
# Current window excluded.
grep -q 'cur:0\|cur  ·  0' "$TMP/choose-in" && { echo "FAIL: current window not excluded"; cat "$TMP/choose-in"; exit 1; }
# Blocked sorted first (line 1) with 🔴 badge.
head -1 "$TMP/choose-in" | grep -q $'\uf071' || { echo "FAIL: blocked not first / no 🔴"; cat "$TMP/choose-in"; exit 1; }
# choose returned 0 → jumped to blocked (perm) by IDs + explicit client.
grep -q 'switch-client -c tty0 -t \$1' "$REC" || { echo "FAIL: did not switch to blocked session-id"; cat "$REC"; exit 1; }
grep -q 'select-window -t @1' "$REC" || { echo "FAIL: did not select blocked window-id"; cat "$REC"; exit 1; }

echo "PASS tmux-window-jump"
