---
name: babysit-prs
description: Autonomously keep Greg's open PRs green — no confirmations. Use when Greg says "babysit my PRs", "pilnuj prek", "ogarnij moje prki w tle", invokes /babysit-prs, or runs it under /loop. One pass per invocation - classifies every failing check (flaky e2e → retry, lint/type/unit → fix + commit + push), rebases conflicting PRs, nudges stale pending reviewers on Slack, and fires a macOS notification when reviewers left new comments. NOT for interactive single-PR work (that's pr-work / g-pr-fix-checks / g-pr-respond).
---

# babysit-prs

One autonomous babysitting pass over the user's own open PRs. Designed to run repeatedly under `/loop` (e.g. `/loop 20m /babysit-prs`) in an auto-permission session — so **do not ask for confirmation** for the actions this skill authorizes.

## Authorization scope (overrides the global commit gate)

Invoking this skill IS the explicit authorization to, without asking:

- commit fixes on **PR head branches** (g-commit format, single line, no body)
- push those branches (`git push`, or `--force-with-lease` after a rebase)
- toggle the `run_e2e` label / rerun failed workflow runs
- post ONE Slack review-nudge bump per stale PR (via the `g-pr-bump` skill) into the PR-review thread, tagging only still-pending requested reviewers/teams — see step 5b for the limits

It is NOT authorization to: merge, approve, close, edit PR bodies, reply to reviewers' comment threads (that's `g-pr-respond`), push to `main`/`master`, or touch anyone else's PRs. Never. The ONLY outbound Slack action allowed is the step-5b review-nudge bump (a reply in the PR Review Bot's thread) — never a new top-level channel message, never a DM, never `@here`. If a PR is green and mergeable, report it — merging stays the user's call.

## State file

`~/.cache/babysit-prs.json` — per PR number:

```json
{ "24601": { "sha": "<headSha>", "e2e_retries": 1, "fixed_checks": ["lint"], "comments_seen": 3, "slack_bump": { "<team-slug>": "2026-07-09" } } }
```

- Read it at start (missing/corrupt → treat as `{}`), write it back at the end of the pass.
- When a PR's head SHA changed since last pass → reset that PR's `e2e_retries` and `fixed_checks` (new code = fresh budget). Leave `slack_bump` intact — the 1-bump-per-day limit is about not spamming humans, independent of new pushes.
- `slack_bump` maps each pinged reviewer/team → the ISO date it was last bumped for this PR (used by step 5b to enforce max 1 bump per target per 24h).
- Drop entries for PRs no longer open.

## Pass workflow

### 1. Collect

```bash
gh pr list --author @me --state open \
  --json number,title,isDraft,mergeable,statusCheckRollup,headRefName,baseRefName,url,headRefOid
```

Skip drafts entirely (a red draft is usually intentional WIP). Requires clean `gh auth status` and a git repo with a GitHub remote; if either fails, report and stop.

### 2. Classify each non-draft PR

Priority order per PR (handle the first that applies, comments always checked):

| Condition | Action |
|---|---|
| `mergeable == CONFLICTING` | rebase path (step 3) |
| failing check name matches `e2e` / `playwright` / `E2E` AND `e2e_retries < 2` for this SHA | **flaky retry**: `gh run rerun <run-id> --failed` (reruns only the failed jobs). Do NOT toggle the `run_e2e` label for this — that reruns the *entire* e2e suite, which is wasteful and not what "flaky retry" means. Reserve the label toggle for the "never triggered" case below. Increment `e2e_retries`. Do NOT investigate logs yet. |
| a required StatusContext sits `EXPECTED` ("waiting for status to be reported") AND no e2e CheckRun is running — e2e was never triggered ("E2E tests: skip by label") | toggle the `run_e2e` label (same as flaky retry, but does NOT count against `e2e_retries` — nothing failed, it just never started) |
| failing e2e AND `e2e_retries >= 2` | not flaky anymore → fix path (step 4) |
| failing check matches lint / eslint / prettier / typecheck / tsc / unit / test / build | fix path (step 4) — immediately, no retry ladder |
| checks `PENDING` | leave alone, next pass will see the result |
| green + mergeable | note "ready to merge" in summary (no action) |

### 3. Rebase path (conflicting PR)

Reuse the `g-pr-fix-checks` helper (checkout → rebase → `--force-with-lease` → run_e2e toggle). It's a **project-scoped** skill, so resolve its script relative to the repo — don't assume `~/.claude/skills`:

```bash
FIXCHECKS="$(git rev-parse --show-toplevel)/.claude/skills/g-pr-fix-checks/scripts/update_pr.sh"
[[ -f "$FIXCHECKS" ]] || FIXCHECKS="$HOME/.claude/skills/g-pr-fix-checks/scripts/update_pr.sh"
bash "$FIXCHECKS" <num>
```

- Exit 0 → done, record in summary.
- Exit 2 (conflict) → **`git rebase --abort`**, return to prior branch, notify (step 5). Autonomous mode never guesses conflict resolutions — semantic conflicts are the user's call.

### 4. Fix path (real failing check)

1. Checkout the PR branch in an isolated worktree (`work pr <num>` if available; else `git worktree add`). Never fix on the user's current branch.
2. `gh run view <run-id> --log-failed` (run-id from `statusCheckRollup`) → find the actual error.
3. Fix the cause. Run the failing check locally (the same lint/tsc/test command CI ran) — **a fix isn't a fix until the local run passes**.
4. Commit (g-commit format: `type(scope): subject <gitmoji>`, one line) and push.
5. Record the check in `fixed_checks` for this SHA. **One fix attempt per check per SHA** — if the same check is red again next pass on the same SHA, don't retry: notify and skip. No infinite fix loops.
6. If the log shows the failure is NOT from this PR's diff (base branch broke) → rebase path instead of fixing.

### 5. Comments → notification

For each open PR (drafts included), count outstanding comments the same way `bin/pr-brief` does (unresolved review threads whose last comment isn't the user's + unanswered conversation comments; bots never count). If the count for any PR is **higher** than `comments_seen` in state:

```bash
alerter --title "PR #<num>: <k> new comment(s)" --message "<title>" --sender com.apple.Terminal --timeout 30
```

`<k>` = current outstanding count minus `comments_seen` (the delta, not the total).

One notification per PR with news, then update `comments_seen`. Do NOT auto-reply to threads — responding is `g-pr-respond`, interactive, user-driven.

Also send an alerter notification for: aborted rebase (conflict) and exhausted fix/retry budget — anything that now needs the user.

### 5b. Slack review-nudge (stale review-requests)

Nudge pending reviewers on Slack for a PR that's *ready* but sitting. **Trigger — ALL must hold:**

- not draft, `mergeable != CONFLICTING`, and **no failing or PENDING required checks** (never nag while the PR is red or CI is still running — fix/wait first)
- GitHub still lists `requested_reviewers` and/or `requested_teams` with **no approval** from them (re-check live, same queries as `g-pr-bump` step 2 — never bump someone who already approved)
- for every target you're about to ping, `slack_bump[<target>]` is empty OR its date is **before today** (max 1 bump per PR per target per 24h)

**Send by delegating to the `g-pr-bump` skill** — it owns the GitHub→Slack mapping, PR-thread lookup, and `<!subteam^…>` / `<@…>` mention syntax (all from work-context). Under babysit autonomy, three deltas from g-pr-bump's normal flow:

1. **Do NOT ask for confirmation** — this skill's authorization overrides g-pr-bump's "confirm before posting" gate.
2. **Ping only** the still-pending `requested_reviewers` / `requested_teams` from GitHub. Never anyone not explicitly requested; never a fresh top-level channel message; reply in the PR Review Bot's thread only.
3. **Compose the bump text through the `slack-voice` skill** (humanizer → slack-voice, per global rules) so it reads like Greg, not a bot. One short sentence.

After a successful send, set `slack_bump[<target>] = <today's ISO date>` for each pinged target. If every pending target was already bumped today → skip silently. If g-pr-bump can't locate the PR's Slack thread → skip and note it in the summary (do **not** fall back to a new top-level post).

### 6. Summarize

End every pass with a short per-PR line: what was done (retried e2e 1/2, fixed lint + pushed, rebased, notified 2 comments, bumped reviewers on Slack, ready to merge, skipped draft) — nothing else. When nothing was actionable: one line, "all green / nothing to do".

## Hard guardrails

- Never merge, approve, or close a PR.
- Never push to the base branch; only PR head branches.
- Never `--force` (only `--force-with-lease`, and only right after a rebase).
- Never resolve rebase conflicts autonomously — abort + notify.
- Max 2 e2e retries and 1 fix attempt per check per head SHA. Budget exhausted → notify, skip, let the user decide.
- Never touch drafts (except counting their comments).
- Slack: max **1 review-nudge bump per PR per target per 24h**; only still-pending requested reviewers/teams; reply in the PR Review Bot's thread only (never a new top-level message, DM, or `@here`); text through `slack-voice`. Never bump a PR that's red or has PENDING checks.
- Leave the user's original branch/worktree exactly as found.
