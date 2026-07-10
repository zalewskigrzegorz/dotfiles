#!/usr/bin/env bash
# Flags edits to sensitive or generated files and asks the user to confirm.
# PreToolUse hook for Edit|Write operations.
# Emits an interactive "ask" decision (exit 0) instead of a hard block, so the
# user can approve in the moment when an edit is legitimately needed.
# NOTE: JSON permissionDecision is only honored on exit 0; exit 2 hard-blocks
# and the JSON is ignored.

set -uo pipefail

# YOLO kill-switch — see bin/claude-yolo. If this session ran `claude-yolo on`,
# abstain so the yolo-allow catch-all hook auto-allows (bypasses even absolute denies).
if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-yolo/$CLAUDE_CODE_SESSION_ID" ]; then
  exit 0
fi

PERMISSION_MODE=""

emit() {
  # $1 = decision (ask|deny|allow) ; $2 = reason
  local decision="$1"
  local reason="${2//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
  exit 0
}
emit_guard() {
  # Interactive ask only when a human is at the keyboard (permission_mode=default);
  # otherwise hard-deny so autonomous runs / subagents can't silently write here.
  if [ "$PERMISSION_MODE" = "default" ]; then
    emit ask "$1"
  else
    emit deny "$1 [BLOCKED by auto-mode policy. STOP — do not retry, rephrase, or look for workarounds. Tell Greg to switch to default mode (Shift+Tab) and rerun.]"
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  emit_guard "jq is required for file protection hooks but is not installed."
fi

INPUT=$(cat)
PERMISSION_MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // ""' 2>/dev/null || echo "")
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
[ -z "$FILE_PATH" ] && exit 0

BASENAME=$(basename -- "$FILE_PATH")
# Case-insensitive comparison copy
BASENAME_LC=$(printf '%s' "$BASENAME" | tr '[:upper:]' '[:lower:]')
PATH_LC=$(printf '%s' "$FILE_PATH" | tr '[:upper:]' '[:lower:]')

# Protected basename patterns. Matched case-insensitively via BASENAME_LC.
PROTECTED_PATTERNS=(
  ".env"
  ".env.*"
  "*.pem"
  "*.key"
  "*.crt"
  "*.p12"
  "*.pfx"
  "id_rsa"
  "id_ed25519"
  "credentials.json"
  ".npmrc"
  ".pypirc"
  "package-lock.json"
  "yarn.lock"
  "pnpm-lock.yaml"
  "*.gen.ts"
  "*.generated.*"
  "*.min.js"
  "*.min.css"
)

shopt -s nocasematch 2>/dev/null || true
for pattern in "${PROTECTED_PATTERNS[@]}"; do
  # Using bash case with nocasematch for case-insensitive glob match.
  case "$BASENAME_LC" in
    $pattern)
      emit_guard "Protected file: $BASENAME matches pattern '$pattern'."
      ;;
  esac
done

# Sensitive directories (use lower-cased path for case-insensitive on mac/Windows).
case "$PATH_LC" in
  .git/*|*/.git/*)
    emit_guard "Editing a file inside .git/." ;;
  secrets/*|*/secrets/*)
    emit_guard "Editing a file inside secrets/." ;;
  .env|.env.*|*/.env|*/.env.*)
    emit_guard "Editing a .env file." ;;
  .claude/hooks/*|*/.claude/hooks/*)
    emit_guard "Editing a hook script (these enforce security boundaries)." ;;
  .claude/settings.json|*/.claude/settings.json|.claude/settings.local.json|*/.claude/settings.local.json)
    emit_guard "Editing settings.json — this controls permissions and hooks." ;;
esac

exit 0
