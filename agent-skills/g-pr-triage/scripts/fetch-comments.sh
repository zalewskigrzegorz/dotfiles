#!/usr/bin/env bash
# fetch-comments.sh
# Usage: ./fetch-comments.sh <owner> <repo> <pr_number>
# Outputs: JSON array of all unresolved inline threads (GraphQL), paginated.

set -euo pipefail

OWNER="${1:?owner required}"
REPO="${2:?repo required}"
NUMBER="${3:?pr number required}"

CURSOR=""
ALL_THREADS='[]'

while true; do
  AFTER_ARG=""
  [[ -n "$CURSOR" ]] && AFTER_ARG=", after: \"$CURSOR\""

  RESULT=$(gh api graphql -f query="
query(\$owner:String!,\$repo:String!,\$num:Int!){
  repository(owner:\$owner,name:\$repo){
    pullRequest(number:\$num){
      url
      headRefOid
      reviewThreads(first:100${AFTER_ARG}){
        pageInfo{ hasNextPage endCursor }
        nodes{
          id isResolved isOutdated path line originalLine diffSide
          comments(first:50){
            nodes{
              id databaseId author{login} body url createdAt
              path line originalLine diffHunk
            }
          }
        }
      }
    }
  }
}" -F owner="$OWNER" -F repo="$REPO" -F num="$NUMBER")

  PAGE_THREADS=$(echo "$RESULT" | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]')
  ALL_THREADS=$(jq -n --argjson acc "$ALL_THREADS" --argjson page "$PAGE_THREADS" '$acc + $page')

  HAS_NEXT=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  CURSOR=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor // empty')

  [[ "$HAS_NEXT" != "true" ]] && break
  [[ -z "$CURSOR" ]] && break
done

echo "$ALL_THREADS" | jq 'sort_by(.path, (.line // .originalLine // 0))'
