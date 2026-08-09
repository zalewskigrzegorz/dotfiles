#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Tina: Listen
# @raycast.mode compact
# @raycast.packageName Tina
# @raycast.icon 🎙️
# Push-to-talk into the house assistant. Bind a hotkey to this command in
# Raycast (Greg uses ⌥Space); it records until you stop talking.
exec /opt/homebrew/bin/nu -c 'source ~/.config/nushell/autoload/tina.nu; tina listen'
