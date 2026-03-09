#!/usr/bin/env bash
set -euo pipefail

PR="${1:-}"
if [[ -z "$PR" ]]; then
  echo "Usage: pr_snapshot.sh <PR_NUMBER_OR_URL>" >&2
  exit 2
fi

echo "== PR META =="
gh pr view "$PR" --json \
  number,title,url,author,baseRefName,headRefName,additions,deletions,changedFiles,files,commits \
  --jq '{number,title,url,author:.author.login,base:.baseRefName,head:.headRefName,additions,deletions,changedFiles,files:[.files[].path],commits:[.commits[].oid]}'

echo
echo "== PR DIFFSTAT =="
gh pr diff "$PR" --stat

echo
echo "== PR DIFF (first 400 lines) =="
gh pr diff "$PR" | sed -n '1,400p'
