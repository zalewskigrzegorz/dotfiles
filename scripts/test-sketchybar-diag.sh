#!/usr/bin/env bash
# Self-check for the anomaly logic in bin/sketchybar-diag (its `analyze` mode):
# feeds a synthetic ps stream and asserts which events come out.
set -uo pipefail
diag="$(dirname "$0")/../bin/sketchybar-diag"

SB=/opt/homebrew/opt/sketchybar/bin/sketchybar
# tick <t> <sb pid or -> <yes cputime s> <watcher rss> <extra kids> <vim cputime s> [watcher child cputime s]
tick() {
  echo "TICK $1"
  [[ $2 != - ]] && echo "$2 1 0:01.00 90000 $SB"
  echo "11 ${2/-/1} 0:00.50 11000 lua /x/sketchybarrc"
  echo "12 1 0:00.10 $4 /x/bin/sketchybar-watcher/sketchybar-watcher"
  echo "13 11 0:$(printf '%05.2f' "$3") 900 yes"
  echo "14 1 0:00.10 47000 /usr/bin/osascript -l JavaScript /x/bin/sketchybar-display-listener"
  echo "15 11 0:00.00 2000 /opt/homebrew/bin/sketchybar --set foo label=bar"
  for ((k = 0; k < $5; k++)); do echo "$((30 + k)) 11 0:00.00 1000 /bin/sh /x/plugins/p.sh"; done
  [[ -n "${7:-}" ]] && echo "40 12 0:$(printf '%05.2f' "$7") 1000 /bin/sh /x/hot.sh"
  # an editor on a sketchybar file is not part of the tree, however hot
  echo "99 1 0:$(printf '%05.2f' "$6") 5000 /usr/bin/vim /x/bin/sketchybar-diag"
}

got=$({
  tick 100 10 0 1000 0 0 0
  tick 102 10 2 1100 3 2 2     # yes 100%, 6 children (lua, yes, cli, 3 sh)
  tick 104 10 4 1300 3 4 4
  tick 106 10 6 1300 0 6 6     # CPU fires (3rd hot sample), watcher rss grew 1000->1300
  tick 108 10 6 1300 0 8 8     # yes idle -> CPU-END
  tick 110 20 6 1300 0 10     # restart 10 -> 20, the hot watcher child exits
  tick 112 - 6 1300 0 12      # gone
  tick 114 21 6 1300 0 14     # back
} | CPU_PCT=50 CPU_TICKS=3 CHILD_MAX=4 CHILD_TICKS=2 RSS_EVERY=1 RSS_N=3 RSS_GROWTH=1.2 "$diag" analyze)

fail=0
expect() { grep -qF -- "$1" <<<"$got" || { echo "FAIL: missing '$1'"; fail=1; }; }
refuse() { grep -qF -- "$1" <<<"$got" && { echo "FAIL: unexpected '$1'"; fail=1; }; }

expect "CPU yes pid 13 at 100% for 3 samples"
expect "CPU-END yes pid 13 back under 50% after 2s"
expect "CPU-END sh pid 40 exited after 4s hot"
expect "CHILDREN 6 processes under sketchybar pid 10 (max 4)"
expect "RSS sketchybar-watcher pid 12 only grew 0M -> 1M over 3 checkpoints"
expect "RESTART sketchybar pid 10 -> 20"
expect "  before 108 kids="
expect "GONE sketchybar pid 20 is gone"
expect "BACK sketchybar is back as pid 21"
refuse "vim"
refuse "pid 15"
[[ $(grep -c '^END$' <<<"$got") == 3 ]] || { echo "FAIL: want 3 END markers"; fail=1; }

(( fail )) && { echo "--- output:"; echo "$got"; exit 1; }
echo "ok: sketchybar-diag analyze"
