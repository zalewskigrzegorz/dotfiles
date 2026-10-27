#!/usr/bin/env bash
# PostToolUse(Bash): a command that went to the background (run_in_background or
# Ctrl+B) gets a tuios window following its output file in less, so Greg sees and
# searches the same log the agent watches. The window stays after the task ends.
set -u
[ -n "${TUIOS_SESSION:-}" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v tuios >/dev/null 2>&1 || exit 0

in=$(cat)
id=$(printf '%s' "$in" | jq -r '.tool_response.backgroundTaskId // empty')
[ -n "$id" ] || exit 0
sid=$(printf '%s' "$in" | jq -r '.session_id')
desc=$(printf '%s' "$in" | jq -r '.tool_input.description // "bg"' | cut -c1-30)

# shortcut: the payload has no output path, so it is globbed from the layout
# Claude Code 2.1 uses (/private/tmp/claude-<uid>/<project>/<sid>/tasks); fix the glob if it moves.
for f in /private/tmp/claude-"$(id -u)"/*/"$sid"/tasks/"$id".output; do
  [ -e "$f" ] || exit 0
  # less +F follows like tail -F; Ctrl+C stops following so / searches, F resumes.
  # tuios's own scrollback editor (prefix+E) garbles the screen on 0.11.1.
  tuios new-window -s "$TUIOS_SESSION" "bg: $desc" --no-focus -- less -R -~ +F "$f" >/dev/null 2>&1
  exit 0
done
