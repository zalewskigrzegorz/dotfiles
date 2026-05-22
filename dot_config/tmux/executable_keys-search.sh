#!/usr/bin/env bash
# keys-search.sh
# Interactive fzf-tmux popup over `tmux list-keys` — bound to prefix+?.
# Replaces tmux's default static `list-keys` output with searchable view.
# Zero maintenance: always reflects current bindings live from the server.
#
# Usage from tmux.conf (after TPM init):
#   unbind-key -T prefix ?
#   bind-key -T prefix ? run-shell 'bash -lc "~/.config/tmux/keys-search.sh"'

set -euo pipefail

# Trim the repetitive `bind-key    -T <table> ` prefix so each row reads
# as `<table>  <key>  <command>` — easier to scan and to fzf against.
tmux list-keys \
  | sed -E 's/^bind-key +-(r|N) +/bind-key  /; s/^bind-key +-T +([^ ]+) +/\1\t/' \
  | fzf-tmux -p 90%,80% \
      --prompt='tmux key> ' \
      --header='prefix+? — search bindings (Esc to dismiss)' \
      --no-sort \
      --tiebreak=begin \
      --delimiter='\t' \
  || true
