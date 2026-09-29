#!/bin/bash
# scan-private-identifiers — deny an Edit/Write into the PUBLIC dotfiles repo
# whose new content matches the private gitleaks rules (company and product
# names, work hosts). The pre-commit gitleaks hook catches the same thing, but
# only after ~8 turns of writing; this fires at the moment of writing.
# 2026-09-25: the company name landed in agent-rules/shared-local-docker.md
# five times before pre-commit stopped it.
#
# Not bypassed by YOLO: nothing here blocks Greg's work, it blocks a leak.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
command -v gitleaks >/dev/null 2>&1 || exit 0
CFG="${DOTFILES_SECRET_DIR:-$HOME/.local/state/dotfiles/secrets}/gitleaks-private.toml"
[ -f "$CFG" ] || exit 0

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
case "$FILE" in
  "$HOME"/Code/dotfiles/*) ;;
  *) exit 0 ;;
esac
case "$FILE" in
  *"/.chezmoidata/"*|*"/secrets/"*) exit 0 ;;   # gitignored private data lives there on purpose
esac

if [ "$TOOL" = "Write" ]; then
  CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty')
elif [ "$TOOL" = "Edit" ]; then
  CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // empty')
else
  exit 0
fi
[ -n "$CONTENT" ] || exit 0

if ! printf '%s' "$CONTENT" | gitleaks stdin --config "$CFG" --redact --no-banner --exit-code 1 >/dev/null 2>&1; then
  reason="This write into the public dotfiles repo contains a private identifier (company, product or work host per gitleaks-private.toml). Use \$WORK_COMPANY / \$WORK_* or a placeholder like <co>; see CLAUDE.md 'Secrets & private data'."
  jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
fi
exit 0
