#!/usr/bin/env bash
# Count WindowServer stalls minute by minute: one line per minute, stops after N minutes (default 10).
# Usage: ws-stall-count.sh [minutes=10]
set -euo pipefail
mins=${1:-10}
for ((i = 1; i <= mins; i++)); do
  sleep 60
  n=$(log show --last 1m --style compact \
    --predicate 'process == "WindowServer" AND eventMessage CONTAINS "timed out"' 2>/dev/null \
    | grep -c 'timed out' || true)
  printf '%s  min %d/%d  timeouts=%s\n' "$(date +%H:%M:%S)" "$i" "$mins" "$n"
done
