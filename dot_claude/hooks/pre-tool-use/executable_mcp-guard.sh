#!/usr/bin/env bash
# Classifies MCP tool calls per Greg's permission policy. PreToolUse hook wired
# with matcher "mcp__.*" in settings.json.
#
# Tiers (redesigned 2026-07-31, spec: bazgroly/dotfiles/specs/
# 2026-07-31-permissions-auto-yolo-design.md):
#   read-only MCP (list/get/search/query/describe/…) → allow silently.
#   mutating  MCP (send/create/update/set/control/…) → allow in acceptEdits/auto
#             (the point of an auto mode), ask in default/plan, deny where nobody
#             can answer (dontAsk/bypassPermissions/unknown → headless/subagent).
#   destructive MCP (delete/clear/remove/kill/…)     → ask in every interactive
#             mode, deny where nobody can answer.
#   anything not clearly read-only → treated as mutating (fail safe).
#
# Empirically verified 2026-07-31: hook "ask" prompts fine in acceptEdits/auto —
# it is NOT auto-resolved to allow.
#
# JSON permissionDecision is honored only on exit 0.

set -uo pipefail

# YOLO kill-switch — see bin/claude-yolo. If this session ran `claude-yolo on`,
# abstain so the yolo-allow catch-all hook auto-allows (bypasses even absolute denies).
if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-yolo/$CLAUDE_CODE_SESSION_ID" ]; then
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
PERMISSION_MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // ""' 2>/dev/null || echo "")

# Only act on MCP tools; let everything else fall through.
case "$TOOL_NAME" in
  mcp__*) ;;
  *) exit 0 ;;
esac

# Trusted MCP servers — fully local, side-effect-bounded to their own canvas/state.
# Skip verb classification entirely and let settings.allow decide. Without this
# early-exit the MUT regex matches verbs like `create_element` / `update_element`
# / `set_*` / `batch_create_*` and forces `ask` even though `mcp__draw__*` is
# in permissions.allow (hook ASK overrides settings allow).
case "$TOOL_NAME" in
  mcp__draw__*) exit 0 ;;
  mcp__claude-in-chrome__*) exit 0 ;;
  # Homey get_*/list_* — read-only; MUT regex false-positives on "schedule" noun.
  mcp__Homey__get_*|mcp__Homey__list_*|mcp__Homey__device_state|mcp__Homey__home_report) exit 0 ;;
  # Hindsight memory layer — the whole memory conversation (recall/reflect/retain/
  # list/get/mental-model ops) is intended use and MUST work in auto mode. Only the
  # destructive wipes fall through to verb classification below.
  mcp__hindsight__delete_*|mcp__hindsight__clear_*) ;;
  mcp__hindsight__*) exit 0 ;;
esac

emit() {
  local decision="$1" reason="${2//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
  exit 0
}

emit_guard() {
  # Ask in every mode with a human at the keyboard; deny where nobody can answer.
  case "$PERMISSION_MODE" in
    default|acceptEdits|auto|plan)
      emit ask "$1" ;;
    *)
      emit deny "$1 [Blocked: no human available to approve in mode '${PERMISSION_MODE:-unknown}'. Do not retry or work around — report this to Greg.]" ;;
  esac
}

emit_soft() {
  # Mutating-but-not-destructive: auto modes flow, default/plan ask.
  case "$PERMISSION_MODE" in
    acceptEdits|auto)
      emit allow "$1 (auto mode)" ;;
    default|plan)
      emit ask "$1" ;;
    *)
      emit deny "$1 [Blocked: no human available to approve in mode '${PERMISSION_MODE:-unknown}'. Do not retry or work around — report this to Greg.]" ;;
  esac
}

NAME_LC=$(printf '%s' "$TOOL_NAME" | tr '[:upper:]' '[:lower:]')

# Destructive verbs: ask even in auto modes (1 click) — data-losing operations.
DESTR='(^|_|-)(delete|del|remove|rm|clear|invalidate|kill|drop|truncate|archive|unpublish)([_-]|$)'
# Mutating verbs win if a name matches both (e.g. batch_create → create).
MUT='(^|_|-)(create|update|set|send|control|turn|press|write|add|sync|schedule|reset|publish|merge|import|restore|duplicate|group|ungroup|lock|unlock|align|distribute|move|draft|upload|put|post|patch|batch|start|stop|cancel|enable|disable|run|exec|execute|generate|toggle|trigger)([_-]|$)'
RO='(^|_|-)(list|get|read|search|query|describe|analyze|find|status|stat|stats|summary|view|fetch|resolve|recommend|follow|traverse|check|coverage|runtime|failing|covered|timeline|show|inspect|diff|count|history|alltests|tests|test|logs|errors|members|reactions|profile|graph|wing|wings|room|rooms|drawer|drawers|tunnel|tunnels)([_-]|$)'

if printf '%s' "$NAME_LC" | grep -qE "$DESTR"; then
  emit_guard "Destructive MCP call: $TOOL_NAME."
elif printf '%s' "$NAME_LC" | grep -qE "$MUT"; then
  emit_soft "Mutating MCP call: $TOOL_NAME."
elif printf '%s' "$NAME_LC" | grep -qE "$RO"; then
  emit allow "Read-only MCP call."
else
  # Unknown verb → fail safe (treat as mutating).
  emit_soft "Unclassified MCP call: $TOOL_NAME (treated as mutating)."
fi
