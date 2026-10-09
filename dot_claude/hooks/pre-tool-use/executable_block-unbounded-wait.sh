#!/bin/bash
# block-unbounded-wait — deny `until|while … sleep …` loops that have no bound.
# A wait loop with no timeout hung ~150 turns (2026-09-27) and twice on CI
# (2026-09-30). Bounded = `timeout` wrapper, or a counter (seq / for i in /
# -lt N / i++ < N). Skipped for run_in_background and under YOLO.
set -uo pipefail
if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-yolo/$CLAUDE_CODE_SESSION_ID" ]; then
  exit 0
fi
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
[ "$(printf '%s' "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null)" = "true" ] && exit 0
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -n "$CMD" ] || exit 0
printf '%s' "$CMD" | grep -qE '(^|[;&|({[:space:]])(until|while)[[:space:]]' || exit 0
printf '%s' "$CMD" | grep -qE '(^|[^[:alnum:]_-])sleep[[:space:]]+[0-9$]' || exit 0
printf '%s' "$CMD" | grep -qE '(^|[;&|({[:space:]])timeout[[:space:]]|(^|[^[:alnum:]_])seq[[:space:]]|for[[:space:]]+\(\(|\$\(\(|\[[[:space:]]+"?\$\{?[a-zA-Z_]+\}?"?[[:space:]]+-(lt|le)[[:space:]]|\+\+[[:space:]]*<' && exit 0
REASON="Unbounded wait loop (until/while + sleep, no timeout or counter). Use the Monitor tool with an until-loop, or wrap it: timeout 600 sh -c '…'. For CI: bin/gh-run-wait <workflow>, timeout 1800 gh run watch <id> --exit-status, or gh pr checks <n> --watch (run_in_background)."
jq -n --arg r "$REASON" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
