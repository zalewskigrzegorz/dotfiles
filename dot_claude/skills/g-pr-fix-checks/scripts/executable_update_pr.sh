#!/usr/bin/env bash
# Rebase a single PR onto its base branch, push, and toggle the run_e2e label.
#
# Usage: update_pr.sh <pr-number>
#
# Exit codes:
#   0 → rebased, pushed, and run_e2e re-triggered (or label missing but the rest succeeded)
#   1 → hard failure (bad args, network, push rejected, etc.) — see stderr
#   2 → rebase hit a conflict; repo left in mid-rebase state, conflicted files printed to stdout
#
# The script intentionally does NOT clean up after a conflict — the calling skill
# (and therefore the AI / user) decides whether to resolve, abort, or hand off.

set -uo pipefail

pr="${1:-}"
if [[ -z "$pr" ]]; then
  echo "usage: update_pr.sh <pr-number>" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found" >&2
  exit 1
fi

# Resolve base branch from the PR metadata so we don't assume main vs master.
base="$(gh pr view "$pr" --json baseRefName -q '.baseRefName' 2>/dev/null || true)"
if [[ -z "$base" ]]; then
  echo "could not read base branch for PR #$pr" >&2
  exit 1
fi

remember_branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
echo "starting branch: ${remember_branch:-<detached>}"

# Refuse to run on a dirty tree — the calling skill is supposed to have handled this,
# but a second check here prevents silent data loss if it didn't.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "working tree is not clean; refusing to checkout the PR branch" >&2
  exit 1
fi

echo "→ checking out PR #$pr"
if ! gh pr checkout "$pr"; then
  echo "gh pr checkout failed for #$pr" >&2
  exit 1
fi

echo "→ fetching origin/$base"
if ! git fetch origin "$base"; then
  echo "git fetch failed for origin/$base" >&2
  exit 1
fi

echo "→ rebasing onto origin/$base"
if ! git rebase "origin/$base"; then
  # Conflict path. Print conflicted files to stdout for the caller to read.
  echo "CONFLICTS:"
  git diff --name-only --diff-filter=U
  exit 2
fi

echo "→ force-push (with lease)"
if ! git push --force-with-lease; then
  echo "git push --force-with-lease failed" >&2
  exit 1
fi

# Toggle run_e2e. Missing-label is not a hard failure — REDACTED_ORG repos have it,
# other repos may not. Report and move on.
e2e_status=0
if ! gh pr edit "$pr" --remove-label run_e2e 2>/dev/null; then
  e2e_status=$((e2e_status + 1))
fi
if ! gh pr edit "$pr" --add-label run_e2e 2>/dev/null; then
  e2e_status=$((e2e_status + 1))
fi

if [[ "$e2e_status" -gt 0 ]]; then
  echo "note: could not toggle run_e2e label on PR #$pr (label may not exist in this repo)"
fi

echo "done: PR #$pr rebased onto $base, pushed, run_e2e toggled"
exit 0
