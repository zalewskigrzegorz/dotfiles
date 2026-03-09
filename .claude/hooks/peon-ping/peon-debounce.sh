#!/bin/bash
# Wrapper: debounce Stop only. Notification always passes (produces the completion popup).
# Cursor fires both for completion; Stop debounce prevents duplicate sound.
set -uo pipefail

INPUT=$(cat)
EVENT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('event', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

PEON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/.debounce.lock"
COOLDOWN_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/.last_stop"

# Debounce Stop only - suppress duplicate Stop within 3s
if [ "$EVENT" = "Stop" ]; then
  exec 9>"$LOCK_FILE"
  flock -x 9 || exit 0
  NOW=$(date +%s)
  LAST=0
  [ -f "$COOLDOWN_FILE" ] && LAST=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo 0)
  if [ "$LAST" -gt 0 ] && [ $((NOW - LAST)) -lt 3 ]; then
    exit 0
  fi
  echo "$NOW" > "$COOLDOWN_FILE"
  exec 9>&-
fi

echo "$INPUT" | exec "$PEON_DIR/peon.sh"
