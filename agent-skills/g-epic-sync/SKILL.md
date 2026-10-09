---
name: g-epic-sync
description: Checks that every sub-issue of the active cycle epic is up to date — state, linked PRs (merged into which base), board Status — and finds cycle-labeled issues that sit outside the epic. Reports mismatches in one table, fixes them after one popup. Use for "sprawdź epika", "czy taski w epiku są zaktualizowane", "epic sync", "zsynchronizuj epika", "check the epic", "are the epic tasks up to date", "co jest nie domknięte w cyklu".
---

# g-epic-sync

Audit the cycle epic against reality. Read-only until Greg picks fixes in one popup.

## Config (private, never hardcode)

`~/.local/state/dotfiles/secrets/work-context.md` → **§ "Slack — cycle daily"**: epic number, board (Projects v2 number, field `Status`), feature branch, cycle start. `source ~/.local/state/dotfiles/secrets/work.env` for `$WORK_MAIN_REPO` and `$WORK_TEAM_LABEL` (the cycle label unless work-context names another).

```bash
source ~/.local/state/dotfiles/secrets/work.env
OWNER=${WORK_MAIN_REPO%/*}; REPO=${WORK_MAIN_REPO#*/}; EPIC=<epic number>; BOARD=<board number>
```

## 1. Sub-issues of the epic

Status option names carry an emoji prefix (`✅Done`): match with `test("Done")`, never `== "Done"`.

```bash
gh api graphql -F owner="$OWNER" -F repo="$REPO" -F epic="$EPIC" -f query='
query($owner:String!,$repo:String!,$epic:Int!){
  repository(owner:$owner,name:$repo){ issue(number:$epic){ subIssues(first:100){ nodes{
    number title state
    projectItems(first:10){ nodes{ project{number}
      status:fieldValueByName(name:"Status"){ ... on ProjectV2ItemFieldSingleSelectValue{ name } } } }
    closedByPullRequestsReferences(first:10, includeClosedPrs:true){
      nodes{ number state merged baseRefName } }
  } } } }
}' | jq --argjson b "$BOARD" '[.data.repository.issue.subIssues.nodes[] | {
    number, title, state,
    status: ([.projectItems.nodes[] | select(.project.number==$b) | .status.name] | first),
    prs: [.closedByPullRequestsReferences.nodes[] | {number, state, merged, base: .baseRefName}] }]'
```

`closedByPullRequestsReferences` = PRs with `Fixes/Closes #n`. A PR merged into the
feature branch (not the default branch) does **not** auto-close the issue.

## 2. Cycle-labeled issues outside the epic

```bash
gh api graphql -f q="repo:$WORK_MAIN_REPO is:issue label:\"$WORK_TEAM_LABEL\" updated:>=<cycle start YYYY-MM-DD>" -f query='
query($q:String!){ search(query:$q,type:ISSUE,first:100){ nodes{ ... on Issue{
  number title state parent{number} } } } }' \
  | jq '[.data.search.nodes[] | select(.parent==null) | {number,title,state}]'
```

Drop the epic itself and issues clearly unrelated to the cycle; list what remains.

## 3. Mismatches (one table)

| Rule | Proposed fix |
|---|---|
| `CLOSED` but board Status not Done | set Status to Done |
| `OPEN` with a merged `Fixes` PR (base = feature branch) | close the issue, Status Done |
| `OPEN`, Status Done | close the issue |
| Cycle label, no parent | add as sub-issue of the epic |

Only mismatches go in the table: `# · title · what is wrong · fix`. Aligned issues
get one line ("N of M sub-issues consistent"). Nothing off: stop there.

## 4. Fix

**One `AskUserQuestion`** (multiSelect) with the fix groups: close issues, add sub-issues, set Done. Apply only the picked ones:

```bash
gh issue close <n> -R "$WORK_MAIN_REPO" -c "Fixed by #<pr>, merged into <base>."
gh api graphql -f query='mutation($i:ID!,$s:ID!){addSubIssue(input:{issueId:$i,subIssueId:$s}){clientMutationId}}' -f i=<epic node id> -f s=<issue node id>
```

Board Status needs project, item, field and option node IDs
(`gh project field-list "$BOARD" --owner "$OWNER" --format json`, `gh project item-list`
then `gh project item-edit`). Fetch them only for the issues Greg picked.

## Rules

- Read-only queries until the popup. Never edit issues or the board on a guess.
- Closing comments and any other outward text go through `greg-voice`.
