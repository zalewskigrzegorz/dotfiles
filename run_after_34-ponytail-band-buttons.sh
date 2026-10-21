#!/usr/bin/env bash
# Drop the Review / Audit / Board / Details buttons from the ponytail band. With the
# alt screen off (CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN in env.nu) Claude gets no mouse,
# so they are dead. /ponytail-review and /ponytail-audit do the same from the prompt.
# Runs every apply because a plugin update ships a fresh register.tsx.
set -euo pipefail

shopt -s nullglob
for f in "$HOME"/.claude/plugins/cache/ponytail/ponytail/*/hooks/band/register.tsx; do
  grep -Eq 'label="(Review|Audit|Board|Details)"' "$f" || continue
  sed -i '' -E '/<Button key="[a-z]+" plain label="(Review|Audit|Board|Details)"/d' "$f"
  echo "ponytail band: buttons removed in $f"
done
