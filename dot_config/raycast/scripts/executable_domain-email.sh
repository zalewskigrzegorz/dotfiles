#!/usr/bin/env bash
set -euo pipefail

# @raycast.schemaVersion 1
# @raycast.title Domain Email
# @raycast.mode compact

# @raycast.icon 📧
# @raycast.packageName Email

# Documentation:
# @raycast.description Builds <apex-domain>@mrglaszki.com from the active browser tab and copies it (e.g. app.figma.com → figma.com@mrglaszki.com)
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

readonly TARGET_DOMAIN='mrglaszki.com'

# Priority order when the frontmost app isn't a browser (e.g. run from the
# Raycast window, where Raycast itself is frontmost). First running browser
# with an open tab wins.
readonly BROWSERS=("Comet" "Zen" "Arc" "Google Chrome" "Brave Browser" "Microsoft Edge" "Vivaldi" "Safari")

# Read the active-tab URL for one app, swallowing AppleScript errors for apps
# that aren't browsers or aren't running. Safari/WebKit vs Chromium differ.
tab_url() {
	local app="$1"
	case "$app" in
		Safari | "Safari Technology Preview")
			osascript -e "tell application \"$app\" to return URL of front document" 2>/dev/null || true ;;
		*)
			osascript -e "tell application \"$app\" to return URL of active tab of front window" 2>/dev/null || true ;;
	esac
}

app_running() {
	osascript -e "tell application \"System Events\" to (name of processes) contains \"$1\"" 2>/dev/null | grep -q true
}

# 1. Frontmost app first — covers running via a bound hotkey with the browser
#    still in focus.
front=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null || true)
url=$(tab_url "$front")

# 2. Fall back to the first running browser from the priority list.
if [[ -z "${url:-}" ]]; then
	for b in "${BROWSERS[@]}"; do
		app_running "$b" || continue
		url=$(tab_url "$b")
		[[ -n "$url" ]] && break
	done
fi

if [[ -z "${url:-}" ]]; then
	echo "Brak URL: żadna znana przeglądarka nie ma otwartej karty." >&2
	exit 1
fi

# host = URL bez schematu/ścieżki, minus www. i port
host=$(awk -F/ '{print $3}' <<<"$url" | sed -E 's/^www\.//; s/:[0-9]+$//')
if [[ -z "$host" ]]; then
	echo "Nie udało się wyciągnąć hosta z: $url" >&2
	exit 1
fi

# apex/registrable domain: 3 człony gdy TLD jest dwuczłonowy (com.pl, co.uk...),
# inaczej 2. Pokrywa PL i najczęstsze ccTLD-y bez Public Suffix List.
if grep -qE '\.(co|com|org|net|gov|edu|ac|biz)\.[a-z]{2}$' <<<"$host"; then
	domain=$(awk -F. '{print $(NF-2)"."$(NF-1)"."$NF}' <<<"$host")
else
	domain=$(awk -F. '{print $(NF-1)"."$NF}' <<<"$host")
fi

result="${domain}@${TARGET_DOMAIN}"
printf '%s' "$result" | pbcopy
printf '%s\n' "$result"
