#!/usr/bin/env bash
# Render a chezmoi .tmpl and byte-diff it against the live target.
# Token-saver: callers get one of {MATCH, DIFF} + the actual diff — no need
# to read both files separately and reason about them.
#
# Usage:
#   render-and-diff.sh <source-tmpl-path-in-chezmoi>
#   render-and-diff.sh <target-path-in-home>
#
# Either side works; we resolve the other via `chezmoi source-path` /
# `chezmoi target-path`.
#
# Exit codes:
#   0 = byte-identical
#   1 = diff (printed to stdout)
#   2 = invocation error

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <source-tmpl-or-target-path>" >&2
  exit 2
fi

input="$1"

# Resolve to absolute path.
if [[ ! -e "$input" ]]; then
  echo "error: path not found: $input" >&2
  exit 2
fi
input="$(cd "$(dirname "$input")" && pwd)/$(basename "$input")"

source_dir="$(chezmoi source-path)"

# Figure out which side the user gave us.
if [[ "$input" == "$source_dir"* ]]; then
  src="$input"
  target="$(chezmoi target-path "$src" 2>/dev/null || true)"
else
  target="$input"
  src="$(chezmoi source-path "$target" 2>/dev/null || true)"
fi

if [[ -z "${src:-}" || -z "${target:-}" ]]; then
  echo "error: could not resolve source<->target pair for $input" >&2
  exit 2
fi

if [[ "$src" != *.tmpl ]]; then
  echo "note: source $src is not a template; falling back to plain diff." >&2
  if diff -q "$src" "$target" >/dev/null 2>&1; then
    echo "MATCH"
    exit 0
  fi
  echo "DIFF"
  diff -u "$src" "$target" || true
  exit 1
fi

rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT

chezmoi execute-template < "$src" > "$rendered"

if diff -q "$rendered" "$target" >/dev/null 2>&1; then
  echo "MATCH  $src  ==  $target"
  exit 0
fi

echo "DIFF   $src  !=  $target"
diff -u "$rendered" "$target" || true
exit 1
