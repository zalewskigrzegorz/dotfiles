#!/usr/bin/env bash
# retro-pending — remember non-trivial sessions that never got a /retro, and
# nudge the next session in the same repo to run `/retro outcome <id>`.
#
#   SessionEnd   → retro-pending.sh end     (records this session if it was non-trivial)
#   SessionStart → retro-pending.sh start   (prints pending sessions for this cwd into context)
#
# Non-trivial = ≥ MIN_PROMPTS human prompts OR ≥ MIN_TOOLS tool calls (an
# autonomous session has one prompt and hundreds of tool calls).
#
# State: $XDG_STATE_HOME/dotfiles/retro-pending.tsv  (date \t session_id \t summary \t cwd)
# A SessionEnd hook's stdout is never shown, so the reminder is deferred to the
# next SessionStart, whose stdout lands in Claude's context.
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
FILE="$STATE_DIR/retro-pending.tsv"
MIN_PROMPTS=6
MIN_TOOLS=40
MAX_AGE_DAYS=14
SHOW=3

command -v jq >/dev/null 2>&1 || exit 0
mkdir -p "$STATE_DIR"
touch "$FILE"

input="$(cat)"
sid="$(jq -r '.session_id // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[[ -n "$sid" && -n "$cwd" ]] || exit 0

drop_sid() { grep -v -F "$1" "$FILE" >"$FILE.tmp"; mv "$FILE.tmp" "$FILE"; }

prune() {
  local cutoff
  cutoff="$(date -v-"${MAX_AGE_DAYS}"d +%F 2>/dev/null || date -d "-${MAX_AGE_DAYS} days" +%F)"
  awk -F'\t' -v c="$cutoff" '$1 >= c' "$FILE" >"$FILE.tmp" && mv "$FILE.tmp" "$FILE"
}

case "${1:-}" in
  end)
    tp="$(jq -r '.transcript_path // empty' <<<"$input")"
    [[ -n "$tp" && -r "$tp" ]] || exit 0
    # Human prompts: `type: user` entries whose content is a string, or an array
    # of text blocks without a tool_result (pasted images etc.). One JSON line each.
    prompts="$(jq -c '
      select(.type=="user") | .message.content
      | if type=="string" then .
        elif type=="array" and (any(.[]; .type=="tool_result") | not) then ([.[] | .text? // empty] | join(" "))
        else empty end
      | select(length > 0)' "$tp" 2>/dev/null)"
    n_prompts="$(printf '%s\n' "$prompts" | sed '/^$/d' | wc -l | tr -d ' ')"
    n_tools="$(jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$tp" 2>/dev/null | wc -l | tr -d ' ')"
    # A session that ran /retro clears the sessions it replayed, and is not itself pending.
    # Typed as text (`claude -p "/retro …"`) the prompt is the literal string; the
    # interactive slash command renders as
    #   <command-name>/retro:retro</command-name>\n<command-args>outcome <id> …</command-args>
    # so match both shapes.
    ran_retro=0
    if printf '%s\n' "$prompts" | grep -qE '^"/retro\b|<command-name>/retro(:retro)?</command-name>'; then
      ran_retro=1
      # Ids it worked on: named after `outcome` in a prompt or command-args, or
      # referenced by any tool call (a sweep over a pending transcript reads
      # <id>.jsonl). Deliberately not the nudge text — that lists every pending id
      # and would clear sessions nobody looked at.
      done_sids="$( {
        printf '%s\n' "$prompts" | grep -oE 'outcome [0-9a-f-]{36}' | awk '{print $2}'
        jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .input | tostring' "$tp" 2>/dev/null \
          | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
      } | sort -u)"
      for done_sid in $done_sids; do
        [[ "$done_sid" != "$sid" ]] && drop_sid "$done_sid"
      done
    fi
    if [[ "$ran_retro" -eq 0 ]] && { [[ "$n_prompts" -ge "$MIN_PROMPTS" ]] || [[ "$n_tools" -ge "$MIN_TOOLS" ]]; }; then
      drop_sid "$sid"
      printf '%s\t%s\t%s prompts, %s tool calls\t%s\n' "$(date +%F)" "$sid" "$n_prompts" "$n_tools" "$cwd" >>"$FILE"
    fi
    prune
    ;;
  start)
    prune
    # Newest first = reverse append order.
    rows="$(awk -F'\t' -v c="$cwd" -v s="$sid" '$4 == c && $2 != s' "$FILE" | awk '{ a[NR] = $0 } END { for (i = NR; i > 0; i--) print a[i] }')"
    [[ -n "$rows" ]] || exit 0
    total="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"
    echo "retro-pending: $total non-trivial session(s) in this repo never got a /retro. Newest first:"
    printf '%s\n' "$rows" | head -n "$SHOW" | awk -F'\t' '{ printf "  /retro outcome %s   (%s, %s)\n", $2, $3, $1 }'
    ;;
  *)
    echo "usage: retro-pending.sh end|start  (hook JSON on stdin)" >&2
    exit 2
    ;;
esac
