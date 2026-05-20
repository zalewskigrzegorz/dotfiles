#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Draw: Present canvas
# @raycast.mode compact
# @raycast.icon 🎬
# @raycast.packageName Homelab Draw

# Documentation:
# @raycast.description Prezentuje aktualny canvas. Próbuje (w kolejności): URL z clipboardu, aktywna karta Chrome/Safari/Arc, ostatni canvas z draw.lab, fallback na draw-mcp
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

set -euo pipefail

extract_canvas_id() {
  # draw.lab URL format (to be verified): http://draw.lab/?canvas=<id> or .../canvas/<id>
  echo "$1" | grep -oE '(canvas[/=])[a-zA-Z0-9_-]+' | head -1 | sed -E 's|^canvas[/=]||'
}

# Try 1: clipboard
CANVAS_ID=$(extract_canvas_id "$(pbpaste 2>/dev/null || true)")

# Try 2: active browser tab (Chrome → Arc → Safari)
if [ -z "$CANVAS_ID" ]; then
  for BROWSER in "Google Chrome" "Arc" "Safari"; do
    URL=$(osascript -e "tell application \"$BROWSER\" to if it is running then return URL of active tab of front window" 2>/dev/null || true)
    if [ -n "$URL" ]; then
      ID=$(extract_canvas_id "$URL")
      if [ -n "$ID" ]; then CANVAS_ID="$ID"; break; fi
    fi
  done
fi

# Try 3 skipped (excalidraw-full /api/v2/kv listing endpoint not yet verified).
# If clipboard/tab don't reveal a canvas, fall through to draw-mcp source.

# Decide source
SOURCE="draw-lab"
if [ -z "$CANVAS_ID" ]; then
  SOURCE="draw-mcp"
  PAYLOAD='{"source":"draw-mcp"}'
else
  PAYLOAD="{\"source\":\"draw-lab\",\"canvasId\":\"$CANVAS_ID\"}"
fi

RESPONSE=$(curl -s -m 10 -X POST http://draw-bridge.lab/scene-to-presentation \
  -H 'Content-Type: application/json' \
  -d "$PAYLOAD")

URL=$(echo "$RESPONSE" | jq -r '.presentUrl // empty')

if [ -z "$URL" ]; then
  ERR=$(echo "$RESPONSE" | jq -r '.error // .')
  osascript -e "display notification \"$ERR\" with title \"Draw: Present failed\" sound name \"Basso\""
  echo "❌ $ERR"
  exit 1
fi

open "$URL"
SRC_LABEL=$([ "$SOURCE" = "draw-mcp" ] && echo "(z MCP — brak canvasu w draw.lab)" || echo "(canvas $CANVAS_ID)")
osascript -e "display notification \"Prezentacja $SRC_LABEL\" with title \"Draw: Presenting\""
echo "✅ $URL  $SRC_LABEL"
