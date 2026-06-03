#!/usr/bin/env bash
# fetch-reviews.sh
# Usage: ./fetch-reviews.sh <owner> <repo> <pr_number>
# Outputs: JSON with PR-level review bodies + deduplicated inline comments,
# including inline only reachable via per-review endpoint (CodeRabbit / Gemini mismatch).

set -euo pipefail

OWNER="${1:?owner required}"
REPO="${2:?repo required}"
NUMBER="${3:?pr number required}"
REPO_FULL="$OWNER/$REPO"

REVIEWS=$(gh api "repos/$REPO_FULL/pulls/$NUMBER/reviews?per_page=100" \
  --jq '[.[] | select(.body | length > 0) | {
    id,
    user: .user.login,
    state,
    submitted_at,
    body
  }]')

BOT_PATTERN="coderabbitai|gemini-code-assist|copilot"

INLINE_COMMENTS=$(gh api "repos/$REPO_FULL/pulls/$NUMBER/comments?per_page=100" \
  --jq '[.[] | select(.in_reply_to_id == null) | {id, path, user: .user.login, created_at, body: .body[0:200]}]')

EXTRA_COMMENTS='[]'

while IFS= read -r REVIEW; do
  BOT_LOGIN=$(echo "$REVIEW" | jq -r '.user')
  REVIEW_ID=$(echo "$REVIEW" | jq -r '.id')
  REVIEW_BODY=$(echo "$REVIEW" | jq -r '.body')

  echo "$BOT_LOGIN" | grep -qE "$BOT_PATTERN" || continue

  # "Actionable comments posted: N" — portable (no grep -P for macOS BSD grep)
  EXPECTED=0
  if printf '%s' "$REVIEW_BODY" | grep -q 'Actionable comments posted'; then
    EXPECTED=$(printf '%s' "$REVIEW_BODY" | sed -n 's/.*Actionable comments posted:[[:space:]]*\([0-9][0-9]*\).*/\1/p' | head -1)
    [[ -z "$EXPECTED" || ! "$EXPECTED" =~ ^[0-9]+$ ]] && EXPECTED=0
  fi
  [[ "$EXPECTED" -eq 0 ]] && continue

  FOUND=$(echo "$INLINE_COMMENTS" | jq --arg u "$BOT_LOGIN" '[.[] | select(.user == $u)] | length')

  if [[ "$FOUND" -lt "$EXPECTED" ]]; then
    REVIEW_INLINE=$(gh api "repos/$REPO_FULL/pulls/$NUMBER/reviews/$REVIEW_ID/comments?per_page=100" \
      --jq '[.[] | select(.in_reply_to_id == null) | {id, path, user: .user.login, created_at, body: .body[0:200]}]')
    EXTRA_COMMENTS=$(jq -n --argjson a "$EXTRA_COMMENTS" --argjson b "$REVIEW_INLINE" '$a + $b | unique_by(.id)')
  fi
done < <(echo "$REVIEWS" | jq -c '.[]')

ALL_INLINE=$(jq -n --argjson a "$INLINE_COMMENTS" --argjson b "$EXTRA_COMMENTS" '$a + $b | unique_by(.id)')

jq -n \
  --argjson reviews "$REVIEWS" \
  --argjson inline "$ALL_INLINE" \
  '{reviews: $reviews, inline_comments: $inline}'
