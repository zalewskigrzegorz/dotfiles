#!/usr/bin/env bash
# Tests for bin/secret-in: hidden prompt, 0600 file, path guard, empty input.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SCRIPT="$HERE/../secret-in"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
DIR="$TMP/scratchpad/secrets"
VAL='dummy-not-a-secret-42'

out=$(pty-run --input "$VAL" -- "$SCRIPT" "$DIR/rds") || true
[ "$(cat "$DIR/rds" 2>/dev/null)" = "$VAL" ] || { echo "FAIL #1 value not written"; exit 1; }
[ "$(stat -f %Lp "$DIR/rds")" = "600" ] || { echo "FAIL #1 mode $(stat -f %Lp "$DIR/rds")"; exit 1; }
case "$out" in *"$VAL"*) echo "FAIL #1 value echoed to the terminal"; exit 1 ;; esac
case "$out" in *"zapisane: rds"*) ;; *) echo "FAIL #1 no confirmation: $out"; exit 1 ;; esac

out=$(pty-run --input '' -- "$SCRIPT" "$DIR/empty")
case "$out" in *"exit=1"*) ;; *) echo "FAIL #2 empty input: $out"; exit 1 ;; esac
[ -e "$DIR/empty" ] && { echo "FAIL #2 file written for empty input"; exit 1; }

"$SCRIPT" "$TMP/elsewhere/x" 2>/dev/null; rc=$?
[ "$rc" = "2" ] || { echo "FAIL #3 path outside scratchpad/secrets, rc=$rc"; exit 1; }
"$SCRIPT" "$DIR/a/b" 2>/dev/null; rc=$?
[ "$rc" = "2" ] || { echo "FAIL #4 nested name, rc=$rc"; exit 1; }

echo "PASS"
