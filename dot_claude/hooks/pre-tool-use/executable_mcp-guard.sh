#!/usr/bin/env bash
# Classifies MCP tool calls per Greg's permission policy. PreToolUse hook wired
# with matcher "mcp__.*" in settings.json.
#
#   read-only MCP (list/get/search/query/describe/…) → allow silently.
#   mutating  MCP (send/create/update/set/control/…) → ask a human in interactive
#             `default` mode; hard-deny in any autonomous mode (auto/subagent/etc.)
#             where a hook "ask" would be auto-resolved to allow.
#   anything not clearly read-only → treated as mutating (fail safe → ask/deny).
#
# JSON permissionDecision is honored only on exit 0.

set -uo pipefail

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
esac

emit() {
  local decision="$1" reason="${2//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
  exit 0
}

NAME_LC=$(printf '%s' "$TOOL_NAME" | tr '[:upper:]' '[:lower:]')

# Mutating verbs win if a name matches both (e.g. batch_create → create).
MUT='(^|_|-)(create|update|delete|del|set|send|control|turn|press|write|add|remove|rm|invalidate|sync|schedule|reset|clear|publish|merge|import|restore|duplicate|group|ungroup|lock|unlock|align|distribute|move|draft|upload|put|post|patch|batch|start|stop|cancel|enable|disable|run|exec|execute|kill|generate|toggle|trigger)([_-]|$)'
RO='(^|_|-)(list|get|read|search|query|describe|analyze|find|status|stat|stats|summary|view|fetch|resolve|recommend|follow|traverse|check|coverage|runtime|failing|covered|timeline|show|inspect|diff|count|history|alltests|tests|test|logs|errors|members|reactions|profile|graph|wing|wings|room|rooms|drawer|drawers|tunnel|tunnels)([_-]|$)'

if printf '%s' "$NAME_LC" | grep -qE "$MUT"; then
  if [ "$PERMISSION_MODE" = "default" ]; then
    emit ask "Mutating MCP call: $TOOL_NAME."
  else
    emit deny "Mutating MCP call: $TOOL_NAME [BLOCKED by auto-mode policy. STOP — do not retry, rephrase, or look for workarounds. Tell Greg to switch to default mode (Shift+Tab) and rerun.]"
  fi
elif printf '%s' "$NAME_LC" | grep -qE "$RO"; then
  emit allow "Read-only MCP call."
else
  # Unknown verb → fail safe (treat as mutating).
  if [ "$PERMISSION_MODE" = "default" ]; then
    emit ask "Unclassified MCP call: $TOOL_NAME (treated as mutating)."
  else
    emit deny "Unclassified MCP call: $TOOL_NAME [BLOCKED by auto-mode policy. STOP — do not retry, rephrase, or look for workarounds. Tell Greg to switch to default mode (Shift+Tab) and rerun.]"
  fi
fi
