#!/bin/bash
# tmux-fzf-url picker script
# Extracts URLs from current tmux pane and opens selected one in browser

# Extract URLs from current pane
URLS=$(tmux capture-pane -J -p \
  | sed -E "s/\x1B\[[0-9;]*[mK]//g" \
  | grep -oE "(https?://[^[:space:]\"'<>]+|www\.[^[:space:]\"'<>]+)" \
  | sed -E "s#^www\.#https://www.#" \
  | sort -u)

# Check if any URLs found
if [ -z "$URLS" ]; then
  tmux display-message "tmux-url-picker: no URLs found"
  exit 0
fi

# Show fzf picker
CHOSEN=$(printf "%s\n" "$URLS" | fzf --tmux center,60%,30% --prompt="URL> " --exit-0)

# Check if user cancelled
if [ -z "$CHOSEN" ]; then
  tmux display-message "tmux-url-picker: cancelled"
  exit 0
fi

# Open selected URL
open "$CHOSEN" &
