#!/bin/bash
# PR watch for Gzyms. bin/pr-watch (launchd) writes ~/.cache/pr-watch-chip.json:
#   {"fix":1,"merge":2,"comments":3,"run":0,"prs":7}
# This prints the pill when that file changes and opens GitHub on a click.
# Protocol: one JSON line per change on stdout, {"event":"click"} lines on stdin, stdin EOF = Gzyms quit.
chip="$HOME/.cache/pr-watch-chip.json"

count() { /usr/bin/plutil -extract "$1" raw -o - "$chip" 2>/dev/null || echo 0; }

pill() {
  local fix merge comments run text="" color=green
  fix=$(count fix); merge=$(count merge); comments=$(count comments); run=$(count run)
  [ "$fix" -gt 0 ] && text="$text ✗ $fix"
  [ "$merge" -gt 0 ] && text="$text ✓ $merge"
  [ "$comments" -gt 0 ] && text="$text 💬 $comments"
  [ "$run" -gt 0 ] && text="$text ⏳ $run"
  if [ -z "$text" ]; then echo '{"item":{"id":"prs","remove":true}}'; return; fi
  # The chip's urgency order: needs a fix > a comment waits > CI runs > ready to merge.
  if [ "$fix" -gt 0 ]; then color=peach; elif [ "$comments" -gt 0 ]; then color=sky; elif [ "$run" -gt 0 ]; then color=gold; fi
  echo "{\"item\":{\"id\":\"prs\",\"text\":\"${text# }\",\"icon\":\"arrow.triangle.pull\",\"color\":\"$color\",\"tooltip\":\"✗ to fix · ✓ ready to merge · 💬 comments waiting · ⏳ CI running\"}}"
}

# Background: print again when the counts file changes (checked every 5 s, a stat only).
(
  last=""
  while true; do
    m=$(/usr/bin/stat -f %m "$chip" 2>/dev/null || echo none)
    if [ "$m" != "$last" ]; then last=$m; pill; fi
    sleep 5
  done
) &
watcher=$!
trap 'kill $watcher 2>/dev/null' EXIT

# Foreground: clicks. When Gzyms quits, stdin ends and so does this loop.
while read -r line; do
  case "$line" in
    *'"click"'*) /usr/bin/open "https://github.com/pulls" ;;
  esac
done
