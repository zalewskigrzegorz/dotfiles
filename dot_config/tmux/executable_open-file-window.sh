#!/usr/bin/env bash
# open-file-window.sh
# Replaces tmux-fzf-open-files-nvim's broken open-in-current-window flow.
# Captures file paths from pane(s), shows fzf popup, opens selection in a
# NEW tmux window — matching the nu `_tui_window` wrapper style (icon name,
# automatic-rename off, focus switched to the new window).
#
# Wired from tmux.conf as prefix+F/H/G overrides (after TPM init).
#
# Modes:
#   visible  — visible portion of the active pane (prefix+F)
#   history  — full scrollback of the active pane (prefix+H)
#   all      — full scrollback of every pane in the active window (prefix+G)

set -euo pipefail

PLUGIN_DIR="${HOME}/.config/tmux/plugins/tmux-fzf-open-files-nvim"
# Reuse the plugin's regex + sanitize helpers so parsing stays consistent.
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/scripts/awk_pane_files.sh"
# shellcheck source=/dev/null
source "${PLUGIN_DIR}/scripts/sanitize.sh"

mode="${1:-visible}"

capture_pane() {
  case "$mode" in
    visible) tmux capture-pane -J -p ;;
    history) tmux capture-pane -J -S- -E- -p ;;
    all)
      tmux list-panes -F '#{pane_id}' | while IFS= read -r pid; do
        tmux capture-pane -t "$pid" -J -S- -E- -p
      done
      ;;
    *)
      tmux display-message "open-file-window: unknown mode '$mode'"
      exit 1
      ;;
  esac
}

files=$(capture_pane | parse_files | sanitize_pane_output | awk 'NF' | awk '!seen[$0]++')

if [[ -z "$files" ]]; then
  tmux display-message "No file paths found in pane ($mode)"
  exit 0
fi

# Use fzf-tmux (ships with fzf) instead of `tmux display-popup -E "fzf ..."`.
# display-popup's quoting under run-shell was returning exit 2 in this setup;
# fzf-tmux makes its own popup and returns the selection straight to stdout.
# fzf-tmux exits 130 on Esc cancel — `|| exit 0` catches that cleanly.
selection=$(printf '%s\n' "$files" | fzf-tmux -p 70%,60% -m --prompt='open in nvim> ') || exit 0
[[ -z "$selection" ]] && exit 0

# sanitize.sh's handle_home_folder_expansion replaces literal `~` with the
# literal string `$HOME`. Undo it here so nvim gets a real filesystem path.
# read-loop instead of `mapfile` — env bash under tmux run-shell may resolve
# to /usr/bin/bash (3.2 on macOS) which lacks mapfile.
selected=()
while IFS= read -r line; do
  selected+=("$line")
done < <(printf '%s\n' "$selection" | sed "s|\\\$HOME|$HOME|g")

# Build nvim args, honouring `file:line:col` jump syntax (e.g. rg/grep output).
args=()
for f in "${selected[@]}"; do
  if [[ "$f" =~ ^([^:]+):([0-9]+):([0-9]+)$ ]]; then
    args+=("+call cursor(${BASH_REMATCH[2]},${BASH_REMATCH[3]})" "${BASH_REMATCH[1]}")
  else
    args+=("$f")
  fi
done

# Spawn a new tmux window in the format used by the nu _tui_window wrapper:
#   icon (nf-custom-vim U+E62B) + "  nvim", automatic-rename off, focus on new window.
icon=$'\xee\x98\xab' # nf-custom-vim (U+E62B) as UTF-8 bytes \u2014 bash 3.2 safe
name="${icon}  nvim"
wid=$(tmux new-window -d -P -F '#{window_id}' -n "$name" -c "${PWD:-$HOME}" nvim -p "${args[@]}")
tmux set-window-option -t "$wid" automatic-rename off
tmux rename-window -t "$wid" "$name"
tmux select-window -t "$wid"
