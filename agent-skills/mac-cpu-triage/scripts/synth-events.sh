#!/usr/bin/env bash
# Count WindowServer "prohibited from synthesizing" events (an event-tap app flooding fake input) per minute over the last N minutes, plus the peak.
# Usage: synth-events.sh [minutes=10]
set -euo pipefail
mins=${1:-10}
log show --last "${mins}m" --style compact \
  --predicate 'process == "WindowServer" AND eventMessage CONTAINS "prohibited from synthesizing"' 2>/dev/null \
  | { grep 'prohibited from synthesizing' || true; } | cut -c1-16 | sort | uniq -c \
  | awk '{print; if ($1 > max) {max = $1; at = $2" "$3}} END {printf "total minutes=%d  peak=%d at %s\n", NR, max, at}'
