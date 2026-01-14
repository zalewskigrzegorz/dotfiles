#!/bin/bash

# File watcher for kindaVim mode changes
# This script monitors kindaVim's environment.json and updates sketchybar

KINDAVIM_ENV_FILE="$HOME/Library/Application Support/kindaVim/environment.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/kindavim.sh"

# Function to update sketchybar
update_sketchybar() {
    "$UPDATE_SCRIPT"
}

# Initial update
update_sketchybar

# Monitor file changes using fswatch if available, otherwise poll
if command -v fswatch &> /dev/null; then
    # Use fswatch for efficient file monitoring
    fswatch -o "$KINDAVIM_ENV_FILE" | while read; do
        # Check if kindaVim is still running before updating
        if pgrep -x "kindaVim" > /dev/null; then
            update_sketchybar
        else
            # kindaVim stopped, clear mode
            /opt/homebrew/bin/sketchybar --trigger kindavim_update MODE=""
        fi
    done
else
    # Fallback to polling if fswatch is not available
    LAST_MODIFIED=""
    while true; do
        # Check if kindaVim is running
        if pgrep -x "kindaVim" > /dev/null; then
            if [ -f "$KINDAVIM_ENV_FILE" ]; then
                CURRENT_MODIFIED=$(stat -f "%m" "$KINDAVIM_ENV_FILE" 2>/dev/null || stat -c "%Y" "$KINDAVIM_ENV_FILE" 2>/dev/null)
                if [ "$CURRENT_MODIFIED" != "$LAST_MODIFIED" ]; then
                    update_sketchybar
                    LAST_MODIFIED="$CURRENT_MODIFIED"
                fi
            else
                # File doesn't exist but kindaVim is running, update anyway
                update_sketchybar
            fi
        else
            # kindaVim is not running, clear mode
            /opt/homebrew/bin/sketchybar --trigger kindavim_update MODE=""
            LAST_MODIFIED=""
        fi
        sleep 0.3
    done
fi

