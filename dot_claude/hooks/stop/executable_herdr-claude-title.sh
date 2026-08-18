#!/usr/bin/env bash
# herdr tab / statusline title — bootstrap + reset only (drives bin/hd-title).
#
# The AGENT owns the title at checkpoints (it calls `hd-title` directly when it
# starts a new task / hits a checkpoint). This hook only keeps a sensible default
# so the tab is never blank or stale:
#
#   * UserPromptSubmit — if nothing is set yet for this session, seed the title
#     from the first prompt (a decent default until the agent sets a checkpoint).
#   * SessionStart source=clear — reset the TEXT to the repo/branch. The colour
#     stays (same session, same colour slot), which is the whole point.
#
# No per-turn churn: the native aiTitle is frozen on the session's first topic,
# so mirroring it every Stop just re-pinned a stale label. Idempotent, non-blocking.
set -u

command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

sid=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] && export CLAUDE_CODE_SESSION_ID="$sid"
sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -n "$sid" ] || exit 0

event=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
cwd=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)

HD=$(command -v hd-title 2>/dev/null || echo "$HOME/Code/dotfiles/bin/hd-title")
[ -x "$HD" ] || exit 0

store="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-session-title/$sid"

# Neutral default: current branch (unless it's the default branch), else repo name.
default_title() {
  local d="${1:-$PWD}" root branch
  root=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)
  branch=$(git -C "$d" branch --show-current 2>/dev/null)
  if [ -n "$root" ] && [ -n "$branch" ] && [ "$branch" != "master" ] && [ "$branch" != "main" ]; then
    printf '%s' "$branch"
  elif [ -n "$root" ]; then
    basename "$root"
  else
    basename "${d:-$PWD}"
  fi
}

case "$event" in
  SessionStart)
    src=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null)
    # Reset stale text on /clear; the colour is untouched. Other sources no-op so
    # a resumed session keeps whatever title it had.
    [ "$src" = "clear" ] && "$HD" "$(default_title "$cwd")"
    ;;
  UserPromptSubmit)
    # Bootstrap from the first prompt only when nothing is set yet.
    if [ ! -s "$store" ]; then
      prompt=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null \
                | sed -e 's/^<command-name>[^<]*<\/command-name>[[:space:]]*//' \
                      -e 's/<[^>]*>//g' -e 's/^[[:space:]>›]*//' \
                | tr '\n' ' ' | sed -e 's/[[:space:]]\{2,\}/ /g' -e 's/[[:space:]]*$//')
      [ -n "$prompt" ] && "$HD" "$prompt"
    fi
    ;;
esac

exit 0
