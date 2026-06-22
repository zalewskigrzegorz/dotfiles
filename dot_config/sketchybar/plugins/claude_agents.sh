#!/usr/bin/env bash
# Emits sketchybar update for the claude_agents chip: ⏳<waiting> ●<running>.
# Driven by the item's `script` (update_freq + routine/forced events). Reads the
# shared agent state via claude-agent-state; hides the chip when no agents.
set -u
export PATH="/opt/homebrew/bin:$PATH"
STATE="$HOME/Code/dotfiles/bin/claude-agent-state"
w=0; r=0
while IFS=$'\t' read -r st _ _; do
  case "$st" in waiting) w=$((w + 1)) ;; running) r=$((r + 1)) ;; esac
done < <("$STATE" list 2>/dev/null || true)

if [ "$w" = 0 ] && [ "$r" = 0 ]; then
  sketchybar --set "$NAME" drawing=off
else
  label=""
  [ "$w" -gt 0 ] && label="⏳$w"
  [ "$r" -gt 0 ] && label="${label:+$label }●$r"
  sketchybar --set "$NAME" drawing=on label="$label"
fi
