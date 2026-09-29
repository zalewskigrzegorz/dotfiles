#!/bin/bash
# actionlint-workflows — before a `git commit` or `git push`, lint the changed
# GitHub Actions workflow files and surface the findings as a message. Never
# blocks: a wrong `on:` event still gets to the user's decision, but they see
# it BEFORE the push instead of after three "0 jobs" runs (2026-09-25).
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
command -v actionlint >/dev/null 2>&1 || exit 0
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
printf '%s' "$COMMAND" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?(commit|push)([[:space:]]|$)' || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0
files=$( { git diff --name-only --cached; git diff --name-only; git diff --name-only @{upstream}..HEAD 2>/dev/null; } | grep -E '^\.github/workflows/.*\.ya?ml$' | sort -u)
[ -n "$files" ] || exit 0
existing=()
while IFS= read -r f; do [ -f "$f" ] && existing+=("$f"); done <<<"$files"
[ ${#existing[@]} -gt 0 ] || exit 0

out=$(actionlint -no-color "${existing[@]}" 2>&1 | head -30)
[ -n "$out" ] || exit 0
jq -n --arg m "actionlint found problems in changed workflow files (not blocking):"$'\n'"$out" '{systemMessage:$m}'
exit 0
