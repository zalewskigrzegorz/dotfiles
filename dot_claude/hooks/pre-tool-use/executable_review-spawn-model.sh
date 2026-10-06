#!/usr/bin/env bash
# review-spawn-model — a review subagent spawned without the Sonnet/Fable
# popup (rule 3a in agent-rules/subagents-on-sonnet.md) gets a permission
# prompt that names the model, so Greg can still pick before it runs. The rule
# text alone was missed once: a whole-branch review went out on Sonnet with no
# popup (retro 2026-10-06, b90f720d).
#
# Fires only for an Agent call whose description or subagent_type says
# "review", and only where Greg is at the keyboard (default/plan/acceptEdits).
# Silent when the session already asked a popup mentioning Fable in its last
# transcript entries, in YOLO, in auto, and headless.
set -uo pipefail

if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-yolo/$CLAUDE_CODE_SESSION_ID" ]; then
  exit 0
fi
command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
[ "$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')" = "Agent" ] || exit 0

case "$(printf '%s' "$INPUT" | jq -r '.permission_mode // ""')" in
  default | plan | acceptEdits) ;;
  *) exit 0 ;;
esac

TYPE=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // ""')
DESC=$(printf '%s' "$INPUT" | jq -r '.tool_input.description // ""')
case "$TYPE" in Explore | fork) exit 0 ;; esac
printf '%s\n%s' "$TYPE" "$DESC" | grep -qi 'review' || exit 0

TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""')
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] &&
  tail -n 80 "$TRANSCRIPT" |
  jq -c 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="AskUserQuestion") | .input' 2>/dev/null |
  grep -qi 'fable'; then
  exit 0
fi

MODEL=$(printf '%s' "$INPUT" | jq -r '.tool_input.model // "inherit"')
jq -n --arg m "$MODEL" --arg d "$DESC" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:("Review spawn \"" + $d + "\" on model: " + $m + ". Rule 3a: Sonnet (cheap) or Fable (deeper)? Allow runs it as is; deny and name the model to switch.")}}'
exit 0
