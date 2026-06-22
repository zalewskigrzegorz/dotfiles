#!/usr/bin/env bash
# Emits sketchybar update for the claude_agents chip: 🔴<blocked> ⏳<waiting>
# ●<running>. Driven by the item's `script` (update_freq + routine/forced events).
# Reads the shared agent state via claude-agent-state; hides when no agents.
set -u
export PATH="/opt/homebrew/bin:$PATH"
STATE="$HOME/Code/dotfiles/bin/claude-agent-state"
# Exclude the window you're currently on — the chip means "agents needing you
# ELSEWHERE", matching the click action (tmux-window-jump skips it too).
CUR=$(tmux display-message -p '#{session_name}:#{window_index}' 2>/dev/null || true)
b=0; w=0; r=0
while IFS=$'\t' read -r st tg _; do
  [ -n "$CUR" ] && [ "$tg" = "$CUR" ] && continue
  case "$st" in blocked) b=$((b + 1)) ;; waiting) w=$((w + 1)) ;; running) r=$((r + 1)) ;; esac
done < <("$STATE" list 2>/dev/null || true)

if [ "$b" = 0 ] && [ "$w" = 0 ] && [ "$r" = 0 ]; then
  sketchybar --set "$NAME" drawing=off
else
  label=""
  [ "$b" -gt 0 ] && label="🔴$b"
  [ "$w" -gt 0 ] && label="${label:+$label }⏳$w"
  [ "$r" -gt 0 ] && label="${label:+$label }●$r"
  sketchybar --set "$NAME" drawing=on label="$label"
fi
