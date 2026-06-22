#!/usr/bin/env bash
# Tests for notify-waiting.sh: writes `waiting` state, plays sound, no banner.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
HOOK="$HERE/../../dot_claude/hooks/notification/executable_notify-waiting.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Shim alerter, tmux, afplay, sketchybar → record args, never touch the real system.
for c in alerter tmux afplay sketchybar; do
  cat >"$TMP/$c" <<EOF
#!/usr/bin/env bash
echo "$c \$*" >> "\$REC"
EOF
  chmod +x "$TMP/$c"
done
export REC="$TMP/rec"

# State write: notify-waiting must call claude-agent-state set waiting.
export CLAUDE_AGENT_STATE_BIN="$TMP/state-rec"
cat >"$TMP/state-rec" <<EOF
#!/usr/bin/env bash
echo "state \$*" >> "\$REC"
EOF
chmod +x "$TMP/state-rec"
: > "$REC"
printf '{"cwd":"%s","message":"need input"}' "$TMP" | PATH="$TMP:$PATH" bash "$HOOK"
grep -q 'state set waiting' "$REC" || { echo "FAIL: no state write"; cat "$REC"; exit 1; }
grep -q 'alerter' "$REC" && { echo "FAIL: alerter banner not removed"; cat "$REC"; exit 1; }
echo "PASS notify-waiting state+no-banner"
