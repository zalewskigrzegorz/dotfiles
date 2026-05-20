#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Draw: Full pipeline
# @raycast.mode compact
# @raycast.icon 🚀
# @raycast.packageName Homelab Draw

# Documentation:
# @raycast.description Pełen pipeline: aktualny scene z MCP → nowy canvas w draw.lab → otwarta prezentacja
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

set -euo pipefail

RESPONSE=$(curl -s -m 15 -X POST http://draw-bridge.lab/full-pipeline \
  -H 'Content-Type: application/json' \
  -d '{}')

PRESENT_URL=$(echo "$RESPONSE" | jq -r '.presentUrl // empty')
CANVAS_URL=$(echo "$RESPONSE" | jq -r '.canvasUrl // empty')

if [ -z "$PRESENT_URL" ]; then
  ERR=$(echo "$RESPONSE" | jq -r '.error // .')
  osascript -e "display notification \"$ERR\" with title \"Draw: Pipeline failed\" sound name \"Basso\""
  echo "❌ $ERR"
  exit 1
fi

open "$PRESENT_URL"
osascript -e "display notification \"Canvas zapisany + prezentacja otwarta\" with title \"Draw: Pipeline OK\""
echo "✅ Canvas: $CANVAS_URL"
echo "✅ Present: $PRESENT_URL"
