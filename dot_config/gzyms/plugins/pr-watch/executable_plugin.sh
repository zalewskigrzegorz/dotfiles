#!/bin/bash
# PR watch for Gzyms, 1:1 with the SketchyBar chip. bin/pr-watch (launchd, every 60–180 s) classifies the PRs and
# writes ~/.cache/pr-watch-*.json; render.nu turns them into the pill, its list and notifications.
# Clicks reuse bin/pr-watch-open: a row opens the PR (an event a failed job's log), a right click jumps to the
# branch's tuios session, a right click on the pill opens gh-dash.
# Protocol: JSON lines out, {"event":"click|right_click|open","id":…} lines in, stdin EOF = Gzyms quit.
export PATH="/opt/homebrew/bin:$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
here="$(cd "$(dirname "$0")" && pwd)"
open_pr="$HOME/Code/dotfiles/bin/pr-watch-open"
files=("$HOME/.cache/pr-watch-chip.json" "$HOME/.cache/pr-watch-last.json" "$HOME/.cache/pr-watch-alerts.json" "$HOME/.cache/pr-watch-alerts-shown.json")

render() { nu "$here/render.nu"; }

# Background: render again when any cache file changes (a stat every 3 s).
(
  last=""
  while true; do
    now=$(/usr/bin/stat -f %m "${files[@]}" 2>/dev/null | tr '\n' ' ')
    if [ "$now" != "$last" ]; then last=$now; render; fi
    sleep 3
  done
) &
watcher=$!
trap 'kill $watcher 2>/dev/null' EXIT

# A cache key is owner/repo#num: only that shape reaches pr-watch-open.
key_ok() { [[ "$1" =~ ^[A-Za-z0-9._/-]+#[0-9]+$ || "$1" =~ ^[0-9]+$ ]]; }

while read -r line; do
  event=$(printf '%s' "$line" | /usr/bin/plutil -extract event raw -o - - 2>/dev/null)
  id=$(printf '%s' "$line" | /usr/bin/plutil -extract id raw -o - - 2>/dev/null)
  button=left; [ "$event" = "right_click" ] && button=right
  case "$event:$id" in
    open:prs)
      # what a click on the SketchyBar chip did: this batch is seen now, and a fresh poll runs in the background
      nu "$here/render.nu" seen; render
      ("$HOME/Code/dotfiles/bin/pr-watch" >/dev/null 2>&1 &) ;;
    right_click:prs) BUTTON=right "$open_pr" >/dev/null 2>&1 & ;;
    *:pr:*) k=${id#pr:}; key_ok "$k" && BUTTON=$button "$open_pr" __row "$k" >/dev/null 2>&1 & ;;
    *:ev:*) k=${id#ev:}; key_ok "$k" && BUTTON=$button "$open_pr" __ev "$k" >/dev/null 2>&1 & ;;
  esac
done
