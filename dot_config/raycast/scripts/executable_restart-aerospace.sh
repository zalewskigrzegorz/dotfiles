#!/usr/bin/env bash

# @raycast.schemaVersion 1
# @raycast.title Restart AeroSpace
# @raycast.mode compact
# @raycast.icon 🪟
# @raycast.packageName Window Management
# @raycast.description Force-kill AeroSpace.app and relaunch — useful when the in-app Leader+X rebind is unreachable (because AeroSpace itself is dead).
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

if pgrep -x AeroSpace >/dev/null 2>&1; then
  killall -9 AeroSpace 2>/dev/null || true
  sleep 1
fi
open -a AeroSpace
echo "AeroSpace relaunched"
