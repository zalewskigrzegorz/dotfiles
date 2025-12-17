#!/bin/bash

# Start the kindaVim mode watcher
# This should be run when sketchybar starts or manually

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHER_SCRIPT="$SCRIPT_DIR/kindavim_watcher.sh"

# Check if watcher is already running
if pgrep -f "kindavim_watcher.sh" > /dev/null; then
    echo "kindaVim watcher is already running"
    exit 0
fi

# Start watcher in background
nohup "$WATCHER_SCRIPT" > /dev/null 2>&1 &
echo "kindaVim watcher started (PID: $!)"
echo "To stop: pkill -f kindavim_watcher.sh"









