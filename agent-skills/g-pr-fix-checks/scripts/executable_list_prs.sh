#!/usr/bin/env bash
# List the current user's open PRs in the current repo with rolled-up check status.
# Output, one PR per line, tab-separated:
#   <number>\t<state>\t<headRefName>\t<baseRefName>\t<title>
# State is one of: FAILING, PENDING, PASSING, UNKNOWN.
# The PR matching the current branch (if any) is listed first.

set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh not authenticated; run: gh auth login" >&2
  exit 1
fi

if ! gh repo view >/dev/null 2>&1; then
  echo "not inside a GitHub repo (gh repo view failed)" >&2
  exit 1
fi

current_branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

# Pull open PRs authored by the current user along with the rolled-up check status.
# statusCheckRollup is an array; we reduce it to a single state below via jq.
raw="$(gh pr list \
  --state open \
  --author '@me' \
  --json number,title,headRefName,baseRefName,statusCheckRollup \
  --limit 200)"

# Reduce statusCheckRollup to one of FAILING / PENDING / PASSING / UNKNOWN.
# - FAILING if any check has conclusion FAILURE / TIMED_OUT / CANCELLED / ACTION_REQUIRED / STARTUP_FAILURE
# - else PENDING if any check is still running (status != COMPLETED, or no conclusion yet)
# - else PASSING if there is at least one check and all are SUCCESS / NEUTRAL / SKIPPED
# - else UNKNOWN (no checks reported)
echo "$raw" | jq -r --arg cb "$current_branch" '
  def roll(checks):
    if (checks | length) == 0 then "UNKNOWN"
    else
      (checks | map(
        # GitHub check runs use .conclusion / .status; status contexts use .state.
        (.conclusion // .state // "") | ascii_upcase
      )) as $cs
      | if ($cs | any(. == "FAILURE" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE" or . == "ERROR")) then "FAILING"
        elif (checks | any(((.status // "") | ascii_upcase) != "COMPLETED" and ((.conclusion // "") == ""))) then "PENDING"
        elif ($cs | any(. == "PENDING" or . == "QUEUED" or . == "IN_PROGRESS" or . == "WAITING" or . == "REQUESTED")) then "PENDING"
        elif ($cs | all(. == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED" or . == "")) then "PASSING"
        else "UNKNOWN"
        end
    end;

  . as $prs
  | map(. + {state: roll(.statusCheckRollup)})
  # Put the current-branch PR first (if any), keep the rest in API order.
  | (map(select(.headRefName == $cb))) + (map(select(.headRefName != $cb)))
  | .[]
  | [.number, .state, .headRefName, .baseRefName, .title] | @tsv
'
