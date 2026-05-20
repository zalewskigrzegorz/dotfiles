#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Draw: Present canvas
# @raycast.mode compact
# @raycast.icon 🎬
# @raycast.packageName Homelab Draw

# Documentation:
# @raycast.description Prezentuje aktualny canvas z otwartej karty draw.lab (czyta localStorage). Fallback: draw-mcp scene.json.
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

set -euo pipefail

# Read excalidraw-current-canvas-id from the first draw.lab tab found in any
# Chromium-based browser (Arc/Chrome/Brave/Vivaldi).
read_chromium_canvas() {
  local app="$1"
  osascript <<EOF 2>/dev/null || true
tell application "$app"
  if not running then return ""
  repeat with w in windows
    repeat with t in tabs of w
      try
        if URL of t starts with "http://draw.lab" then
          return (execute t javascript "localStorage.getItem('excalidraw-current-canvas-id') || ''")
        end if
      end try
    end repeat
  end repeat
  return ""
end tell
EOF
}

read_safari_canvas() {
  osascript <<'EOF' 2>/dev/null || true
tell application "Safari"
  if not running then return ""
  repeat with w in windows
    repeat with t in tabs of w
      try
        if URL of t starts with "http://draw.lab" then
          return (do JavaScript "localStorage.getItem('excalidraw-current-canvas-id') || ''" in t)
        end if
      end try
    end repeat
  end repeat
  return ""
end tell
EOF
}

CANVAS_ID=""
for APP in "Arc" "Google Chrome" "Brave Browser" "Vivaldi"; do
  CANVAS_ID=$(read_chromium_canvas "$APP")
  CANVAS_ID="${CANVAS_ID//[$'\t\r\n ']/}"
  [ -n "$CANVAS_ID" ] && break
done

if [ -z "$CANVAS_ID" ]; then
  CANVAS_ID=$(read_safari_canvas)
  CANVAS_ID="${CANVAS_ID//[$'\t\r\n ']/}"
fi

if [ -z "$CANVAS_ID" ]; then
  ERR="Otwórz draw.lab w Arc/Chrome/Safari i włącz View → Developer → Allow JavaScript from Apple Events."
  osascript -e "display notification \"$ERR\" with title \"Draw: Present failed\" sound name \"Basso\""
  echo "❌ $ERR"
  exit 1
fi

PAYLOAD="{\"source\":\"draw-lab\",\"canvasId\":\"$CANVAS_ID\"}"

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
osascript -e "display notification \"Prezentacja canvas $CANVAS_ID\" with title \"Draw: Presenting\""
echo "✅ $URL  (canvas $CANVAS_ID)"
