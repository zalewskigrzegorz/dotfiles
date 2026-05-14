#!/usr/bin/env bash
# fetch-comments.sh
# Usage: ./fetch-comments.sh <owner> <repo> <pr_number>
# Outputs: JSON array of all unresolved inline threads (GraphQL), paginated.
#
# Each thread is enriched with:
#   pr_author             — PR author login (same on every thread, for convenience)
#   last_comment_author   — login of the latest comment's author in the thread
#   last_comment_at       — ISO timestamp of the latest comment
#   author_replied_last   — true if PR author wrote the latest comment (likely already handled)
#   reviewer_followed_up  — true if a non-PR-author replied AFTER the PR author's last reply
#                            (i.e. the ball is back in the PR author's court)

set -euo pipefail

OWNER="${1:?owner required}"
REPO="${2:?repo required}"
NUMBER="${3:?pr number required}"

CURSOR=""
ALL_THREADS='[]'
PR_AUTHOR=""

while true; do
  AFTER_ARG=""
  [[ -n "$CURSOR" ]] && AFTER_ARG=", after: \"$CURSOR\""

  RESULT=$(gh api graphql -f query="
query(\$owner:String!,\$repo:String!,\$num:Int!){
  repository(owner:\$owner,name:\$repo){
    pullRequest(number:\$num){
      url
      headRefOid
      author{login}
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

  if [[ -z "$PR_AUTHOR" ]]; then
    PR_AUTHOR=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.author.login // ""')
  fi

  PAGE_THREADS=$(echo "$RESULT" | jq --arg author "$PR_AUTHOR" '
    [.data.repository.pullRequest.reviewThreads.nodes[]
      | select(.isResolved == false)
      | . as $t
      | ($t.comments.nodes | sort_by(.createdAt)) as $sorted
      | ($sorted | last) as $latest
      | ([$sorted[] | select((.author.login // "") == $author)] | last) as $last_author_reply
      | $t + {
          pr_author: $author,
          last_comment_author: ($latest.author.login // null),
          last_comment_at: ($latest.createdAt // null),
          author_replied_last: (($latest.author.login // "") == $author),
          reviewer_followed_up: (
            ($last_author_reply != null)
            and (($latest.author.login // "") != $author)
            and (($latest.createdAt // "") > ($last_author_reply.createdAt // ""))
          )
        }]')
  ALL_THREADS=$(jq -n --argjson acc "$ALL_THREADS" --argjson page "$PAGE_THREADS" '$acc + $page')

  HAS_NEXT=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  CURSOR=$(echo "$RESULT" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor // empty')

  [[ "$HAS_NEXT" != "true" ]] && break
  [[ -z "$CURSOR" ]] && break
done

# Flatten GraphQL-shaped `comments: {nodes: [...]}` to a plain array so downstream
# jq queries can use `.comments[0]`, `.comments[-1]`, `.comments | length` directly.
echo "$ALL_THREADS" | jq '
  sort_by(.path, (.line // .originalLine // 0))
  | map(.comments = (.comments.nodes // []))
'
