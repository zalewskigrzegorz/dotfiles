#!/bin/sh
# PreToolUse (matcher *): keep the Mac awake while any Claude session is
# actively working. Every tool call refreshes a caffeinate "lease" — a
# 15-minute `caffeinate -is` that is restarted once it has less than 5
# minutes left. When no session calls a tool for 15 minutes the lease
# expires on its own and the Mac can sleep again.
#
# Shared across sessions (single pidfile): any active session keeps the
# lease alive. A race between two sessions can spawn a short-lived extra
# caffeinate — harmless, it self-expires via -t.
#
# Attribution: on each fresh spawn we drop a lease file at
# ~/.local/state/caffeine-manager/agents/<pid>.json (same schema + dir the
# Caffeine Manager app reads) so the app shows "Claude Code · <repo>"
# instead of "unknown / external". No MCP needed — the app reads that dir
# directly. Best-effort; a failure here never blocks the tool call.
#
# Never blocks a tool call: any failure exits 0.

[ "$(uname)" = "Darwin" ] || exit 0
command -v caffeinate >/dev/null 2>&1 || exit 0

LEASE_SECS=900    # caffeinate lifetime (15 min)
REFRESH_AGE=600   # restart when older than this (10 min → ≥5 min headroom)

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude"
pidfile="$state_dir/caffeinate.lease"
mkdir -p "$state_dir" 2>/dev/null || exit 0

# Shared attribution dir the Caffeine Manager app reads.
agents_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caffeine-manager/agents"

now=$(date +%s)

if [ -f "$pidfile" ]; then
  read -r pid ts <"$pidfile" 2>/dev/null || ts=0
  case "$pid$ts" in *[!0-9]*) pid=0 ts=0 ;; esac
  if [ "${pid:-0}" -gt 0 ] && kill -0 "$pid" 2>/dev/null && [ $((now - ts)) -lt "$REFRESH_AGE" ]; then
    exit 0  # lease still fresh
  fi
  if [ "${pid:-0}" -gt 0 ]; then
    kill "$pid" 2>/dev/null
    rm -f "$agents_dir/$pid.json" 2>/dev/null  # drop stale attribution
  fi
fi

nohup caffeinate -is -t "$LEASE_SECS" >/dev/null 2>&1 &
new_pid=$!
echo "$new_pid $now" >"$pidfile" 2>/dev/null

# Attribution (best-effort). Repo basename from the session's project dir;
# strip characters that would break the JSON string.
repo=$(basename "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null | tr -d '"\\')
[ -n "$repo" ] || repo="unknown-repo"
if mkdir -p "$agents_dir" 2>/dev/null; then
  tmp="$agents_dir/$new_pid.json.$$.tmp"
  printf '{"pid":%s,"label":"Claude Code · %s","via":"hook","reason":null,"startedAt":%s,"expiresAt":%s}\n' \
    "$new_pid" "$repo" "$((now * 1000))" "$(((now + LEASE_SECS) * 1000))" \
    >"$tmp" 2>/dev/null && mv "$tmp" "$agents_dir/$new_pid.json" 2>/dev/null
fi

exit 0
