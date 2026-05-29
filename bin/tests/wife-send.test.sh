#!/usr/bin/env bash
# Tests for bin/wife-send: clipboard detection, webhook payload, exit codes.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../wife-send"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Shim pbpaste, pngpaste, curl → record args & control behavior via env.
cat >"$TMP/pbpaste" <<'EOF'
#!/usr/bin/env bash
[ -n "${FAKE_PBPASTE:-}" ] && printf '%s' "$FAKE_PBPASTE"
EOF
cat >"$TMP/pngpaste" <<'EOF'
#!/usr/bin/env bash
if [ -n "${FAKE_PNG_BYTES:-}" ]; then
  printf '%s' "$FAKE_PNG_BYTES" > "$1"
  exit 0
else
  exit 1
fi
EOF
cat >"$TMP/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >> "$REC"
echo "${FAKE_HTTP_STATUS:-204}"
EOF
chmod +x "$TMP"/pbpaste "$TMP"/pngpaste "$TMP"/curl
export REC="$TMP/rec"

run() {
  : > "$REC"
  PATH="$TMP:$PATH" \
    WIFE_DISCORD_WEBHOOK="${WEBHOOK-https://discord.test/hook}" \
    FAKE_PBPASTE="${PB:-}" FAKE_PNG_BYTES="${PNG:-}" FAKE_HTTP_STATUS="${HTTP:-204}" \
    "$SCRIPT" "$@"
}

PB="" PNG="" run; rc=$?
[ "$rc" = "1" ] || { echo "FAIL #1 expected exit 1, got $rc"; exit 1; }
[ -s "$REC" ] && { echo "FAIL #1 curl called on empty input"; exit 1; }

PB="hello world" PNG="" run; rc=$?
[ "$rc" = "0" ] || { echo "FAIL #2 expected exit 0, got $rc"; exit 1; }
grep -q 'hello world' "$REC" || { echo "FAIL #2 text not in payload"; cat "$REC"; exit 1; }
grep -q 'application/json' "$REC" || { echo "FAIL #2 no json content-type"; cat "$REC"; exit 1; }

PB="https://example.com" PNG="" run --note "look at this"; rc=$?
[ "$rc" = "0" ] || { echo "FAIL #3 rc=$rc"; exit 1; }
grep -q 'look at this' "$REC" || { echo "FAIL #3 note missing"; exit 1; }
grep -q 'example.com' "$REC" || { echo "FAIL #3 url missing"; exit 1; }

PB="" PNG="fake-png-bytes-here" run; rc=$?
[ "$rc" = "0" ] || { echo "FAIL #4 rc=$rc"; exit 1; }
grep -q -- '-F' "$REC" || { echo "FAIL #4 no multipart"; cat "$REC"; exit 1; }

PB="" PNG="" run --note "just a thought"; rc=$?
[ "$rc" = "0" ] || { echo "FAIL #5 rc=$rc"; exit 1; }
grep -q 'just a thought' "$REC" || { echo "FAIL #5 note-only payload missing"; exit 1; }

WEBHOOK="" PB="text" run; rc=$?
[ "$rc" = "2" ] || { echo "FAIL #6 expected exit 2, got $rc"; exit 1; }

PB="text" HTTP=500 run; rc=$?
[ "$rc" = "3" ] || { echo "FAIL #7 expected exit 3 on HTTP 500, got $rc"; exit 1; }

echo "PASS"
