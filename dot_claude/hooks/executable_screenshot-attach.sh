#!/usr/bin/env bash
# UserPromptSubmit: when the prompt mentions a screenshot, hand the agent the newest CleanShot paths.
dir="$HOME/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Screenshots"
[ -d "$dir" ] || exit 0

prompt=$(jq -r '.prompt // empty')
printf '%s' "$prompt" | grep -qiE '(^|[^[:alnum:]])(screen(y|a|ie|em|ów|ik|shot[[:alnum:]]*)?|ss|zrzut[[:alnum:]]*)([^[:alnum:]]|$)' || exit 0

# Shots from the last 15 min (max 5); none → just the newest one.
recent=$(find "$dir" -maxdepth 1 -type f -mmin -15 \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0 \
  | xargs -0 ls -t 2>/dev/null | head -5)
[ -n "$recent" ] || recent=$(ls -t "$dir"/*.png "$dir"/*.jpg 2>/dev/null | head -1)
[ -n "$recent" ] || exit 0

echo "Greg's latest CleanShot screenshot(s), newest first — Read them before answering:"
printf '%s\n' "$recent"
