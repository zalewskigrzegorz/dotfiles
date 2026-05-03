#!/usr/bin/env bash
set -euo pipefail

setapp_dir="${1:-/Applications/Setapp}"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "Setapp apps are macOS-only." >&2
  exit 0
fi

if [[ ! -d "$setapp_dir" ]]; then
  echo "Setapp apps directory not found: $setapp_dir" >&2
  exit 1
fi

find "$setapp_dir" -maxdepth 1 -type d -name '*.app' -print \
  | sed 's#^.*/##; s#\.app$##' \
  | sort
