#!/usr/bin/env bash
set -euo pipefail

SRC="${1:-}"
BASE="${2:-}"

if [[ -z "$SRC" || -z "$BASE" ]]; then
  echo "Usage: branch_snapshot.sh <source_branch> <base_branch>" >&2
  exit 2
fi

git fetch --all --prune >/dev/null 2>&1 || true

echo "== DIFFSTAT ${BASE}..${SRC} =="
git diff --stat "${BASE}..${SRC}"

echo
echo "== CHANGED FILES ${BASE}..${SRC} =="
git diff --name-only "${BASE}..${SRC}"

echo
echo "== DIFF (first 400 lines) =="
git diff "${BASE}..${SRC}" | sed -n '1,400p'
