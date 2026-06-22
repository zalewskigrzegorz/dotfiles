#!/usr/bin/env bash
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../tmux-window-jump"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export PATH="$TMP/shim:$PATH"; mkdir -p "$TMP/shim"; export REC="$TMP/rec"; : >"$REC"

cat >"$TMP/shim/tmux" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *"list-windows"*) printf 'main:0\tmain  ·  0 zsh\nwork:1\twork  ·  1 claude\n' ;;
  *) echo "tmux \$*" >> "\$REC" ;;
esac
EOF
cat >"$TMP/shim/claude-agent-state" <<EOF
#!/usr/bin/env bash
# work:1 is waiting; main:0 nothing.
[ "\$2" = "--waiting" ] || [ "\$1" = "list" ] && printf 'waiting\twork:1\tredocly ▸ main\n'
EOF
cat >"$TMP/shim/choose" <<EOF
#!/usr/bin/env bash
cat > "$TMP/choose-in"   # capture what would be shown
echo 0                   # pick first row
EOF
cat >"$TMP/shim/claude-focus-session" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/shim/"*
export CLAUDE_AGENT_STATE_BIN="$TMP/shim/claude-agent-state"
export CLAUDE_FOCUS_BIN="$TMP/shim/claude-focus-session"
export TMUX_BIN="$TMP/shim/tmux"
export CHOOSE_BIN="$TMP/shim/choose"

# Case A: --waiting with exactly one waiting → jump immediately, choose NOT called.
"$BIN" --waiting
[ -f "$TMP/choose-in" ] && { echo "FAIL[A]: picker shown for single waiting"; exit 1; }
grep -q 'tmux switch-client -t work' "$REC" || { echo "FAIL[A]: did not jump to work"; cat "$REC"; exit 1; }

# Case B: full picker badges the waiting row with ⏳.
rm -f "$TMP/choose-in"; : >"$REC"
"$BIN"
grep -q '⏳' "$TMP/choose-in" || { echo "FAIL[B]: no badge in picker"; cat "$TMP/choose-in"; exit 1; }

echo "PASS tmux-window-jump"
