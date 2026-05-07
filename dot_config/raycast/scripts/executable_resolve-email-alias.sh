#!/usr/bin/env bash
set -euo pipefail

# @raycast.schemaVersion 1
# @raycast.title Resolve Email Alias
# @raycast.mode compact

# @raycast.icon ✉️
# @raycast.packageName Email

# Documentation:
# @raycast.description Maps maksim009+<tag>@gmail.com to <tag>@zinsoft.bulc.club (argument or clipboard)
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

# @raycast.argument1 { "type": "text", "placeholder": "maksim009+tag@gmail.com", "optional": true }

readonly TARGET_DOMAIN='zinsoft.bulc.club'

trim() {
	local s="$1"
	s="${s#"${s%%[![:space:]]*}"}"
	s="${s%"${s##*[![:space:]]}"}"
	printf '%s' "$s"
}

resolve_candidate() {
	local input="$1"
	local candidate
	candidate=$(trim "$input")
	if [[ "$candidate" =~ ^maksim009\+ ]]; then
		printf '%s' "$candidate"
		return
	fi
	grep -oE 'maksim009\+[A-Za-z0-9._-]+@gmail\.com' <<<"$input" | head -n1 || true
}

raw=$(trim "${1:-}")
if [[ -z "$raw" ]]; then
	raw=$(trim "$(pbpaste 2>/dev/null || printf '')")
fi

if [[ -z "$raw" ]]; then
	echo 'Brak tekstu: podaj adres jako argument lub skopiuj go do schowka.' >&2
	exit 1
fi

candidate=$(resolve_candidate "$raw")
if [[ -z "$candidate" ]]; then
	echo 'Nie znaleziono adresu w formacie maksim009+<tag>@gmail.com.' >&2
	exit 1
fi

if [[ ! "$candidate" =~ ^maksim009\+([A-Za-z0-9._-]+)@gmail\.com$ ]]; then
	echo 'Nieprawidłowy adres (wymagane: maksim009+<tag>@gmail.com).' >&2
	exit 1
fi

tag="${BASH_REMATCH[1]}"
if [[ -z "$tag" ]]; then
	echo 'Tag po znaku + nie może być pusty.' >&2
	exit 1
fi

result="${tag}@${TARGET_DOMAIN}"
printf '%s' "$result" | pbcopy
printf '%s\n' "$result"
