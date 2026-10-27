#!/usr/bin/env bash
# standup-pending — SessionStart nudge, like retro-pending: on a weekday with no
# standup sent yet, say how many work tasks the tuios title hook logged since the
# last one, so the agent can offer /g-standup.
#
# Reads  $XDG_STATE_HOME/dotfiles/claude-task-log.jsonl  (tuios-claude-title.sh)
#        $XDG_STATE_HOME/dotfiles/standup-last           (bin/standup-send, ISO time)
set -u
command -v jq >/dev/null 2>&1 || exit 0
state="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
log="$state/claude-task-log.jsonl"
[ -f "$log" ] && [ "$(date +%u)" -le 5 ] || exit 0

last=$(cat "$state/standup-last" 2>/dev/null)
[ "${last:0:10}" = "$(date +%F)" ] && exit 0

# Work sessions only: the main checkout and its worktrees.
source "$state/secrets/work.env" 2>/dev/null
[ -n "${WORK_PROJECT_DIR:-}" ] || exit 0
n=$(jq -r --arg last "$last" --arg dir "$WORK_PROJECT_DIR" --arg wt "/wt-${WORK_PROJECT_DIR##*/}/" '
      select(.ts > $last)
      | select((.cwd | startswith($dir)) or (.cwd | contains($wt)))
      | .title' "$log" 2>/dev/null | sort -u | wc -l | tr -d ' ')
[ "${n:-0}" -gt 0 ] || exit 0
echo "standup-pending: $n work task(s) logged since the last standup (${last:-never}), today's not sent yet. Mention it to Greg in one line; \`/g-standup\` builds the answers from the task log."
