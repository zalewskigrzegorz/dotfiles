#!/usr/bin/env bash
# Test: claude-focus-session switches tmux silently if a client is attached;
# otherwise activates the existing Ghostty window via osascript (NEVER `open
# -a Ghostty`, which would spawn a fresh window on top of the current one).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BIN="$HERE/../claude-focus-session"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export REC="$TMP/rec"

mk_tmux_ok() {
  cat >"$TMP/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$REC"
exit 0
EOF
  chmod +x "$TMP/tmux"
}
mk_tmux_fail() {
  cat >"$TMP/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$REC"
exit 1
EOF
  chmod +x "$TMP/tmux"
}
cat >"$TMP/osascript" <<'EOF'
#!/usr/bin/env bash
echo "osascript $*" >> "$REC"
EOF
chmod +x "$TMP/osascript"

# Case 1: session arg + tmux switch succeeds → tmux called, NO osascript.
mk_tmux_ok
: > "$REC"
TMUX_BIN="$TMP/tmux" OSASCRIPT="$TMP/osascript" "$BIN" mysess
grep -q 'tmux switch-client -t mysess' "$REC" || { echo "FAIL[1]: no switch-client"; cat "$REC"; exit 1; }
grep -q 'osascript' "$REC" && { echo "FAIL[1]: osascript fired when tmux switch worked (would spawn extra window)"; cat "$REC"; exit 1; }

# Case 2: session arg + tmux switch fails → tmux called AND osascript activate.
mk_tmux_fail
: > "$REC"
TMUX_BIN="$TMP/tmux" OSASCRIPT="$TMP/osascript" "$BIN" mysess
grep -q 'tmux switch-client -t mysess' "$REC" || { echo "FAIL[2]: no switch-client attempt"; cat "$REC"; exit 1; }
grep -q 'osascript .*Ghostty.*activate' "$REC" || { echo "FAIL[2]: osascript activate missing as fallback"; cat "$REC"; exit 1; }

# Case 3: no session arg → no tmux switch, osascript activate fires.
mk_tmux_ok
: > "$REC"
TMUX_BIN="$TMP/tmux" OSASCRIPT="$TMP/osascript" "$BIN"
grep -q 'switch-client' "$REC" && { echo "FAIL[3]: switch-client without session arg"; cat "$REC"; exit 1; }
grep -q 'osascript .*Ghostty.*activate' "$REC" || { echo "FAIL[3]: osascript activate missing (no-arg)"; cat "$REC"; exit 1; }

echo "PASS"
