#!/bin/bash

# This script monitors kindaVim's mode changes and sends updates to sketchybar
# kindaVim stores its mode in ~/Library/Application Support/kindaVim/environment.json

KINDAVIM_ENV_FILE="$HOME/Library/Application Support/kindaVim/environment.json"

# Check if kindaVim process is actually running
if ! pgrep -x "kindaVim" > /dev/null; then
    # kindaVim is not running, clear mode
    sketchybar --trigger kindavim_update MODE=""
    exit 0
fi

# Read the current mode from kindaVim's environment file
# Note: kindaVim only writes persistent modes (normal, insert, visual) to environment.json
# Transient modes (command, replace) are not written to the file and cannot be detected
if [ -f "$KINDAVIM_ENV_FILE" ]; then
    # Extract mode from JSON (e.g., {"mode":"insert"} -> insert)
    MODE=$(cat "$KINDAVIM_ENV_FILE" | grep -o '"mode":"[^"]*"' | cut -d'"' -f4)
    
    # Convert kindaVim mode names to uppercase single letters (like svim)
    case "$MODE" in
        "normal")
            MODE="N"
            ;;
        "insert")
            MODE="I"
            ;;
        "visual")
            MODE="V"
            ;;
        *)
            # Unknown mode - default to empty
            MODE=""
            ;;
    esac
    
    # Send event to sketchybar
    sketchybar --trigger kindavim_update MODE="$MODE"
else
    # No kindaVim active, clear mode
    sketchybar --trigger kindavim_update MODE=""
fi

