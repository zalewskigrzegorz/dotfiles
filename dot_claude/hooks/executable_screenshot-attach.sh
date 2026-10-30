#!/usr/bin/env bash
# UserPromptSubmit: when the prompt mentions a screenshot, hand the agent the newest CleanShot paths.
dirs=("$HOME"/Library/CloudStorage/GoogleDrive-*/"My Drive"/Screenshots)
dir=${dirs[0]}
[ -d "$dir" ] || exit 0

# Only the head of the prompt, so pasted code with "@media screen" doesn't fire it.
prompt=$(jq -r '.prompt // empty' | head -c 200)
# A path he picked himself (/shot) already says which shot: don't add the newest ones.
case $prompt in *"/My Drive/Screenshots/"*) exit 0 ;; esac
printf '%s' "$prompt" | grep -qiE '(^|[^[:alnum:]])(screen(y|a|ie|em|ów|ik|shot[[:alnum:]]*)?|scr|ss|zrzut[[:alnum:]]*)([^[:alnum:]]|$)' || exit 0

# Shots from the last 15 min (max 5); none → just the newest one.
recent=$(find "$dir" -maxdepth 1 -type f -mmin -15 \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0 \
  | xargs -0 ls -t 2>/dev/null | head -5)
# ls on the dir, not a glob: thousands of paths overflow ARG_MAX.
[ -n "$recent" ] || recent=$(ls -t "$dir" | grep -m1 -iE '\.(png|jpe?g)$' | sed "s|^|$dir/|")
[ -n "$recent" ] || exit 0

echo "Greg's latest CleanShot screenshot(s), newest first, with capture time (now $(date +%H:%M))."
echo "Read them before answering. If the newest is older than his message, Drive may not have synced yet: say so."
# CleanShot sometimes writes a .jpeg twin beside the .png: the agent reads only the png.
while IFS= read -r f; do [[ $f == *.jpeg && -e ${f%.jpeg}.png ]] && continue; stat -f '%Sm  %N' -t '%Y-%m-%d %H:%M' "$f"; done <<<"$recent"
