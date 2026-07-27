#!/usr/bin/env bash
# SessionStart (async): warn when live ~/.claude/settings.json drifted from the
# chezmoi template. Claude Code / /config sometimes rewrites the live file
# (dropped keys, reordering) and the next `chezmoi apply` then conflicts or
# silently overwrites — surface it instead of losing changes.
#
# Notifies once per unique diff (hash-throttled), via alerter with osascript
# fallback. Never blocks session start.
set -u

chezmoi_bin="$(command -v chezmoi || echo /opt/homebrew/bin/chezmoi)"
[ -x "$chezmoi_bin" ] || exit 0

diff_out="$("$chezmoi_bin" diff "$HOME/.claude/settings.json" 2>/dev/null)" || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude"
hash_file="$state_dir/settings-drift.hash"
mkdir -p "$state_dir" 2>/dev/null || exit 0

if [ -z "$diff_out" ]; then
  rm -f "$hash_file"
  exit 0
fi

hash="$(printf '%s' "$diff_out" | shasum -a 256 | cut -d' ' -f1)"
[ -f "$hash_file" ] && [ "$(cat "$hash_file" 2>/dev/null)" = "$hash" ] && exit 0
echo "$hash" >"$hash_file"

lines="$(printf '%s\n' "$diff_out" | grep -c '^[+-][^+-]')"
msg="settings.json ≠ chezmoi template (${lines} changed lines). Run: chezmoi diff ~/.claude/settings.json"

if command -v alerter >/dev/null 2>&1; then
  (alerter -title "dotfiles drift" -message "$msg" -timeout 30 >/dev/null 2>&1 &)
elif command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$msg\" with title \"dotfiles drift\"" >/dev/null 2>&1
fi

exit 0
