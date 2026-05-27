#!/usr/bin/env bash
# Test: claude-focus-session calls `tmux switch-client -t <session>` and raises Ghostty.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../claude-focus-session"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Shim tmux + open to record their args.
cat >"$TMP/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$REC"
EOF
cat >"$TMP/open" <<'EOF'
#!/usr/bin/env bash
echo "open $*" >> "$REC"
EOF
chmod +x "$TMP/tmux" "$TMP/open"
export REC="$TMP/rec"

# With a session arg.
TMUX_BIN="$TMP/tmux" OPEN_BIN="$TMP/open" "$BIN" mysess
grep -q 'tmux switch-client -t mysess' "$REC" || { echo "FAIL: no switch-client"; cat "$REC"; exit 1; }
grep -q 'open -a Ghostty' "$REC" || { echo "FAIL: did not raise Ghostty"; exit 1; }

# With no session arg → only raises Ghostty, no switch-client.
: > "$REC"
TMUX_BIN="$TMP/tmux" OPEN_BIN="$TMP/open" "$BIN"
grep -q 'switch-client' "$REC" && { echo "FAIL: switch-client without session"; exit 1; }
grep -q 'open -a Ghostty' "$REC" || { echo "FAIL: did not raise Ghostty (no-arg)"; exit 1; }

echo "PASS"
