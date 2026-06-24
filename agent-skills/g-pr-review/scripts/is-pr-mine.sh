#!/usr/bin/env bash
# is-pr-mine.sh
# Usage: ./is-pr-mine.sh [<pr-number-or-url>]
#   No arg -> resolves the PR for the current branch.
# Prints `true` if the authenticated gh user is the PR author, else `false`.
# Exit code mirrors the answer: 0 = mine, 1 = someone else's, 2 = no PR / error.
# Context (me / author / number) goes to stderr so stdout stays a clean bool.

set -euo pipefail

TARGET="${1:-}"

ME="${G_PR_ME:-$(gh api user --jq .login 2>/dev/null || true)}"
if [[ -z "$ME" ]]; then
  echo "is-pr-mine: gh not authenticated (gh auth login)" >&2
  exit 2
fi

if [[ -n "$TARGET" ]]; then
  PR_JSON=$(gh pr view "$TARGET" --json number,author 2>/dev/null || true)
else
  PR_JSON=$(gh pr view --json number,author 2>/dev/null || true)
fi

if [[ -z "$PR_JSON" ]]; then
  echo "is-pr-mine: no PR found (${TARGET:-current branch})" >&2
  exit 2
fi

NUMBER=$(echo "$PR_JSON" | jq -r '.number')
PR_AUTHOR=$(echo "$PR_JSON" | jq -r '.author.login')

echo "is-pr-mine: me=$ME author=$PR_AUTHOR pr=#$NUMBER" >&2

if [[ "$ME" == "$PR_AUTHOR" ]]; then
  echo true
  exit 0
else
  echo false
  exit 1
fi
