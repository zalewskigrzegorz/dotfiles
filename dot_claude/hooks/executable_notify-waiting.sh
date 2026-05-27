#!/usr/bin/env bash
# Notification hook — fires when Claude Code is waiting on the user (permission
# prompt, idle, or MCP elicitation). Posts a native macOS notification owned by
# Ghostty (via alerter): title = "repo ▸ worktree ▸ branch", body = what's asked,
# click = switch to the originating tmux session. macOS-only; never blocks.
set -u

command -v jq >/dev/null 2>&1 || exit 0
[ "$(uname -s)" = "Darwin" ] || exit 0

INPUT=$(cat)
NTYPE=$(printf '%s' "$INPUT" | jq -r '.notification_type // ""' 2>/dev/null || echo "")
case "$NTYPE" in
  permission_prompt|idle_prompt|elicitation_dialog) ;;
  *) exit 0 ;;
esac

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
MSG=$(printf '%s' "$INPUT" | jq -r '.message // "Claude is waiting"' 2>/dev/null || echo "Claude is waiting")
[ -n "$CWD" ] || CWD="$PWD"

ALERTER="${ALERTER:-alerter}"
TMUX_BIN="${TMUX_BIN:-/opt/homebrew/bin/tmux}"
FOCUS="${CLAUDE_FOCUS_SESSION:-/Users/greg/Code/dotfiles/bin/claude-focus-session}"

# ── Title: repo ▸ worktree ▸ branch ──────────────────────────────────────
title="Claude is waiting"
worktree=""
if command -v git >/dev/null 2>&1 && git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  toplevel=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)
  worktree=$(basename "$toplevel")
  branch=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
  common=$(git -C "$CWD" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
  if [ -n "$common" ]; then repo=$(basename "$(dirname "$common")"); else repo="$worktree"; fi
  if [ "$repo" = "$worktree" ]; then
    title="$repo ▸ $branch"
  else
    title="$repo ▸ $worktree ▸ $branch"
  fi
fi

# ── Resolve tmux session for this cwd ─────────────────────────────────────
sess=$("$TMUX_BIN" list-panes -a -F '#{session_name}	#{pane_current_path}' 2>/dev/null \
  | awk -F'	' -v c="$CWD" '$2==c {print $1; exit}')
if [ -z "$sess" ]; then
  sess=$("$TMUX_BIN" list-panes -a -F '#{session_name}	#{pane_current_path}' 2>/dev/null \
    | awk -F'	' -v c="$CWD/" 'index(c, $2"/")==1 {print $1; exit}')
fi

grp="claude-wait-${sess:-${worktree:-default}}"

# ── Notify via alerter (background; click switches to the session) ────────
"$ALERTER" -title "$title" -message "$MSG" -sender com.mitchellh.ghostty \
  -group "$grp" -timeout 10 -execute "$FOCUS $sess" >/dev/null 2>&1 &

# ── Sound + immediate sketchybar refresh ──────────────────────────────────
sound="$HOME/.claude/hooks/sounds/claude-done.mp3"
[ -f "$sound" ] && (afplay "$sound" >/dev/null 2>&1 &)
command -v sketchybar >/dev/null 2>&1 && sketchybar --trigger claude_sessions_changed 2>/dev/null || true

exit 0
