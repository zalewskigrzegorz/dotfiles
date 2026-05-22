#!/usr/bin/env bash
# ~/Code/dotfiles/test/bin/test-claude-sessions.sh
# Integration test for bin/claude-sessions.
set -euo pipefail

BIN="${BIN:-$HOME/Code/dotfiles/bin/claude-sessions}"
TMP_PROJECTS=$(mktemp -d)
TMP_CACHE=$(mktemp)

cleanup() { rm -rf "$TMP_PROJECTS" "$TMP_CACHE"; }
trap cleanup EXIT

export CLAUDE_PROJECTS_DIR="$TMP_PROJECTS"
export CLAUDE_SESSIONS_CACHE="$TMP_CACHE"

# --- Test 1: fresh state — no projects → count = 0 ---
rm -f "$TMP_CACHE"
out=$("$BIN" count)
[[ "$out" == "0" ]] || { echo "FAIL: count empty != 0 (got: $out)"; exit 1; }
echo "OK: count returns 0 for no projects"

# --- Test 2: one active session → count = 1 ---
mkdir -p "$TMP_PROJECTS/-test-cwd"
cat >"$TMP_PROJECTS/-test-cwd/session1.jsonl" <<'EOF'
{"type":"user_message","content":"hi"}
{"type":"assistant_text_end","content":"hello"}
EOF
# Recent mtime (within ACTIVE_WINDOW_SEC)
touch "$TMP_PROJECTS/-test-cwd/session1.jsonl"
rm -f "$TMP_CACHE"

out=$("$BIN" count)
[[ "$out" == "1" ]] || { echo "FAIL: count one active != 1 (got: $out)"; exit 1; }
echo "OK: count returns 1 for one active session"

# --- Test 3: cache hit returns same value on second call (no fs change) ---
out2=$("$BIN" count)
[[ "$out2" == "1" ]] || { echo "FAIL: cached count != 1 (got: $out2)"; exit 1; }
echo "OK: cache hit returns same count"

# --- Test 4: stale session (older than ACTIVE_WINDOW_SEC=600) ignored ---
# Back-date 1 hour using portable timestamp-based approach
old_ts=$(( $(date +%s) - 3600 ))   # 1 hour ago in seconds
# Try macOS BSD `touch -A`, then GNU `touch -d @ts`, then fallback
if ! touch -A -010000 "$TMP_PROJECTS/-test-cwd/session1.jsonl" 2>/dev/null; then
  if ! touch -d "@$old_ts" "$TMP_PROJECTS/-test-cwd/session1.jsonl" 2>/dev/null; then
    # POSIX fallback: derive YYYYMMDDhhmm.SS from epoch
    old_date=$(date -r "$old_ts" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$old_ts" +%Y%m%d%H%M.%S)
    touch -t "$old_date" "$TMP_PROJECTS/-test-cwd/session1.jsonl"
  fi
fi
rm -f "$TMP_CACHE"

out=$("$BIN" count)
[[ "$out" == "0" ]] || { echo "FAIL: stale session counted (got: $out)"; exit 1; }
echo "OK: stale session (>600s) not counted"

# --- Test 5: --json output has tmux_session key ---
# Reset state: ensure we have one active session from earlier tests
touch "$TMP_PROJECTS/-test-cwd/session1.jsonl"
rm -f "$TMP_CACHE"

json=$("$BIN" --json)
echo "$json" | jq -e 'type == "array"' >/dev/null \
  || { echo "FAIL: --json not an array (got: $json)"; exit 1; }
echo "$json" | jq -e '.[0] | has("project") and has("session_id") and has("mtime") and has("waiting") and has("tmux_session")' >/dev/null \
  || { echo "FAIL: --json entry missing required keys (got: $json)"; exit 1; }
echo "OK: --json entry has tmux_session key"

echo "All tests passed ✓"
