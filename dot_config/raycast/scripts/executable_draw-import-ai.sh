#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Draw: Import AI scene
# @raycast.mode compact
# @raycast.icon 🎨
# @raycast.packageName Homelab Draw

# Documentation:
# @raycast.description Kopiuje aktualny scene z draw-mcp do nowego canvasu w draw.lab i otwiera w przeglądarce
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

set -euo pipefail

RESPONSE=$(curl -s -m 10 -X POST http://draw-bridge.lab/import-ai-scene \
  -H 'Content-Type: application/json' \
  -d '{}')

URL=$(echo "$RESPONSE" | jq -r '.url // empty')

if [ -z "$URL" ]; then
  ERR=$(echo "$RESPONSE" | jq -r '.error // .')
  osascript -e "display notification \"$ERR\" with title \"Draw: Import failed\" sound name \"Basso\""
  echo "❌ $ERR"
  exit 1
fi

open "$URL"
osascript -e "display notification \"Otwarte: $URL\" with title \"Draw: AI scene imported\""
echo "✅ $URL"
