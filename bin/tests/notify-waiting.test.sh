#!/usr/bin/env bash
# Tests for notify-waiting.sh: filtering, title derivation, alerter invocation.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
HOOK="$HERE/../../dot_claude/hooks/executable_notify-waiting.sh"
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
# tmux list-panes must yield a session mapping for the repo cwd.
cat >"$TMP/tmux" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "list-panes" ]; then printf '%s\t%s\n' "worksess" "$FAKE_CWD"; else echo "tmux $*" >> "$REC"; fi
EOF
chmod +x "$TMP/tmux"

# A real git repo to derive repo/branch from.
REPO="$TMP/myrepo"; mkdir -p "$REPO"; ( cd "$REPO" && git init -q && git checkout -q -b feat/x && git commit -q --allow-empty -m init )
export FAKE_CWD="$REPO"

run() { # $1 = notification_type, $2 = message
  : > "$REC"
  printf '{"notification_type":"%s","message":"%s","cwd":"%s"}' "$1" "$2" "$REPO" \
   | PATH="$TMP:$PATH" ALERTER="$TMP/alerter" TMUX_BIN="$TMP/tmux" \
     CLAUDE_FOCUS_SESSION="$TMP/focus" bash "$HOOK"
}

# 1) permission_prompt → alerter called with title containing repo+branch, body, group, execute.
run permission_prompt "Allow Bash command execution?"
grep -q 'alerter ' "$REC" || { echo "FAIL: alerter not called"; cat "$REC"; exit 1; }
grep -q 'myrepo' "$REC" || { echo "FAIL: title missing repo"; cat "$REC"; exit 1; }
grep -q 'feat/x' "$REC" || { echo "FAIL: title missing branch"; cat "$REC"; exit 1; }
grep -q 'Allow Bash command execution?' "$REC" || { echo "FAIL: body missing"; exit 1; }
grep -q -- '-group' "$REC" || { echo "FAIL: no -group"; exit 1; }
grep -q -- '-execute' "$REC" || { echo "FAIL: no -execute"; exit 1; }
grep -q 'worksess' "$REC" || { echo "FAIL: session not resolved into execute"; exit 1; }

# 2) auth_success → ignored (no alerter).
run auth_success "Logged in"
grep -q 'alerter ' "$REC" && { echo "FAIL: alerter called for auth_success"; exit 1; }

echo "PASS"
