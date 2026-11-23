---
name: babysit-prs
description: Autonomously keep Greg's open PRs green, one pass, no confirmations. Use for "babysit my PRs", "pilnuj prek", "ogarnij moje prki w tle", /babysit-prs, or under /loop. Retries flaky e2e, fixes lint/type/unit and pushes, rebases conflicting PRs, nudges stale reviewers on Slack, notifies on new comments. NOT for interactive single-PR work (g-pr-fix-checks / g-pr-respond).
---

# babysit-prs

One autonomous pass over Greg's own open PRs, built for `/loop 20m
/babysit-prs` in an auto-permission session: **no confirmations** for what
this skill authorizes.

## Authorized (overrides the commit gate)

Without asking: commit fixes on **PR head branches** (g-commit format, one
line), push them (`--force-with-lease` only right after a rebase), toggle
`run_e2e` / rerun failed runs, and one Slack review-nudge per stale PR (5b).

Never: merge, approve, close, edit PR bodies, reply to review threads
(`g-pr-respond`), push to the base branch or `main`/`master`, touch others' PRs,
resolve rebase conflicts, plain `--force`. The only outbound Slack is the 5b
reply in the PR Review Bot's thread: no top-level message, DM or `@here`.
Green + mergeable is reported; merging is Greg's. Leave his branch/worktree
exactly as found.

## State: `~/.cache/babysit-prs.json`

`{ "24601": { "sha": "<headSha>", "e2e_retries": 1, "fixed_checks": ["lint"], "comments_seen": 3, "slack_bump": { "<team-slug>": "2026-07-09" } } }`

Read at start (missing/corrupt → `{}`), write at the end. Head SHA changed →
reset `e2e_retries` and `fixed_checks`, keep `slack_bump`. Drop closed PRs.

## Pass

### 1. Collect

`gh pr list --author @me --state open --json
number,title,isDraft,mergeable,statusCheckRollup,headRefName,baseRefName,url,headRefOid`.
Needs `gh auth status` and a repo with a GitHub remote, else report and stop.
Drafts: skip (only their comments count, step 5).

### 2. Classify (first match wins)

| Condition | Action |
|---|---|
| `CONFLICTING` | rebase (3) |
| failing `e2e`/`playwright`/`E2E`, `e2e_retries < 2` | `gh run rerun <run-id> --failed`, `e2e_retries++`, no log reading. Not the label toggle (reruns the whole suite) |
| required StatusContext `EXPECTED` and no e2e CheckRun running ("E2E tests: skip by label") | toggle `run_e2e`; doesn't count as a retry |
| failing e2e, retries ≥ 2 | fix (4) |
| failing lint / eslint / prettier / typecheck / tsc / unit / test / build | fix (4) at once |
| `PENDING` | leave |
| green + mergeable | "ready to merge" |

### 3. Rebase

```bash
FIXCHECKS="$(git rev-parse --show-toplevel)/.claude/skills/g-pr-fix-checks/scripts/update_pr.sh"   # project-scoped skill
[[ -f "$FIXCHECKS" ]] || FIXCHECKS="$HOME/.claude/skills/g-pr-fix-checks/scripts/update_pr.sh"
bash "$FIXCHECKS" <num>
```

Exit 0 → done. Exit 2 → `git rebase --abort`, back to the prior branch, notify.

### 4. Fix

1. PR branch in its own worktree via `workctl` (`no-native-worktrees` rule),
   never on Greg's current branch.
2. `gh run view <run-id> --log-failed` → the real error. Not from this PR's
   diff (base broke) → rebase instead.
3. Fix, run the same check locally: **not a fix until it passes**.
4. Commit + push, add the check to `fixed_checks`. **One attempt per check per
   SHA**: red again on the same SHA → notify, skip.

### 5. New comments → notification

Per open PR (drafts too) count outstanding comments like `bin/pr-brief`
(unresolved threads whose last comment isn't Greg's + unanswered conversation
comments, bots never count). Above `comments_seen`:

`alerter --title "PR #<num>: <k> new comment(s)" --message "<title>" --sender com.apple.Terminal --timeout 30`

`<k>` = the delta. Update `comments_seen`. Never auto-reply. Also notify on an
aborted rebase and an exhausted retry/fix budget.

### 5b. Slack review-nudge

All must hold: not draft, not conflicting, no failing or PENDING required
checks; GitHub still lists requested reviewers/teams without their approval
(`g-pr-bump` step 2, live); each target's `slack_bump` date is before today.

Send through `g-pr-bump` with three deltas: no confirmation; ping only the
still-pending requested reviewers/teams; text through `greg-voice`, one short
sentence. Then `slack_bump[<target>] = <today>`. All bumped today → skip
silently. No thread found → skip, note it, never a top-level post.

### 6. Summary

One line per PR (retried e2e 1/2, fixed lint + pushed, rebased, notified 2
comments, bumped reviewers, ready to merge, skipped draft); nothing actionable
→ "all green / nothing to do". People by full name (`work-people`), and an
unanswered thread says whom it waits on. Unattended `workctl` tab: the same
lines as the P10 mail (`../g-pr-common/PRIMITIVES.md`).
