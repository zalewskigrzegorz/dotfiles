#!/bin/bash

# Monitor kindaVim's environment.json file for mode changes
# and update sketchybar accordingly

KINDAVIM_ENV_FILE="$HOME/Library/Application Support/kindaVim/environment.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/kindavim.sh"

# Function to get current mode
get_mode() {
    if [ -f "$KINDAVIM_ENV_FILE" ]; then
        MODE=$(cat "$KINDAVIM_ENV_FILE" | grep -o '"mode":"[^"]*"' | cut -d'"' -f4)
        case "$MODE" in
            "normal") echo "N" ;;
            "insert") echo "I" ;;
            "visual") echo "V" ;;
            "command") echo "C" ;;
            "replace") echo "R" ;;
            *) echo "" ;;
        esac
    else
        echo ""
    fi
}

# Initial mode
LAST_MODE=$(get_mode)
"$UPDATE_SCRIPT"

# Monitor file changes
while true; do
    # Use fswatch if available, otherwise poll
    if command -v fswatch &> /dev/null; then
        fswatch -1 "$KINDAVIM_ENV_FILE" &> /dev/null
    else
        sleep 0.5
    fi
    
    CURRENT_MODE=$(get_mode)
    
    if [ "$CURRENT_MODE" != "$LAST_MODE" ]; then
        "$UPDATE_SCRIPT"
        LAST_MODE="$CURRENT_MODE"
    fi
done

















