---
name: g-pr-respond
description: Answer reviewers on YOUR OWN pull request. Fetches unresolved review threads and bot comments, triages by severity, asks per thread (one popup each, batched only on request), drafts English replies and fix plans, applies fixes, commits via g-commit, posts the replies via gh. Never submits a verdict on your own PR. Use to respond to review feedback, answer reviewers, reply to review threads, or address comments on a PR you opened — current branch, PR number or URL. Someone else's PR → g-pr-review.
---

# g-pr-respond

Answer reviewers on a PR **you authored**: fetch → triage → ask → fix →
commit → push → post replies. **Never** `gh pr review` (GitHub rejects a
self-review; verdicts are `g-pr-review`'s). Replies go to
`…/comments/{id}/replies`.

Read `../g-pr-common/PRIMITIVES.md` now (language, P0–P12). Everything below
assumes it.

## P2. Confirm it's your PR

Only `author.login == me` counts (co-authoring or pushing doesn't); `$ME` from
P0b, `$AUTHOR` from P1.

```bash
[[ "$ME" == "$AUTHOR" ]] && MINE=true || MINE=false
```

`MINE=true` → state it in one line, proceed. `MINE=false` → "This is <full
name>'s PR, not yours — use `g-pr-review`", stop unless Greg overrides ("just
draft author-style replies anyway").

## A1. Fetch

```bash
bash "$SCRIPTS/fetch-comments.sh" "$OWNER" "$REPO" "$NUMBER"   # unresolved threads
bash "$SCRIPTS/fetch-reviews.sh"  "$OWNER" "$REPO" "$NUMBER"   # review bodies + top-level inline
```

Live = `author_replied_last == false` OR `reviewer_followed_up == true`.
Already replied (the rest) is skipped; surface the count, include on "show
already-replied".

## A2. Severity

| Severity | Signals | Stance |
|---|---|---|
| CRITICAL | `🔒 Security`, `🚨`/`🔴 Critical`, security wording | must-fix unless false positive |
| HIGH | `⚠️ Potential issue`, `🐛 Bug`, `⚡ Performance`, `🟠 Major` | should fix |
| MEDIUM | `🛠️ Refactor suggestion`, `💡 Suggestion` | recommended |
| LOW | `🧹 Nitpick`, `🔧 Optional`, `🟡 Minor`, `⚪ Info`, style | optional |

A type label plus a colour badge → the badge wins.

## A3. Summary table, once

| # | Severity | Source | File:line | Author | Status | Rec | O co chodzi | Summary |
|---|---|---|---|---|---|---|---|---|

Status `new` / `awaiting-you` / `already-replied` (on request); Source
`inline` / `review` / `issue`; Rec = the A4 default; "O co chodzi" in Polish:
what the reviewer means, not what they wrote. Cluster per P4. Below it:
`Skipped N already-replied thread(s) — say "show already-replied" to include
them.` (omit at 0). No fix plans or replies yet. Never repeat the table.

## A4. Decisions: one thread per popup

Default, and always on docs, pitch and design PRs:

- Order that unblocks the rest: the thread that changes scope first.
- **Explain before asking**: 2–4 Polish sentences above the popup on what the
  reviewer points at, what the code/pitch says today, what each option costs.
  Verify claims in the code first ("zobacz jak to teraz działa żeby nie pisać
  głupot").
- **Decision forks before drafts**: a thread that changes what we build gets
  its own decision popup; the reply is drafted after, describing the decision.
- A thread questioning the design of Greg's own feature: the recommended
  option defends the goal and fixes the concrete flaws. "Split it out" is never
  recommended unless Greg said so.
- Greg rejects a popup to clarify → answer in prose, then re-ask the same
  popup with the new context.

Options per thread, recommended first: **Apply reviewer's suggestion**
(CRITICAL/HIGH concrete bug, small agreed fix) · **Keep my code, reply
explaining** (taste, nit, out of scope, code is right) · **Different approach —
I'll describe** (valid concern, wrong fix) · **Skip / already handled**
(outdated, duplicate, done later).

**Fast path** only on "szybko", "hurtem", "ogarnij wszystko", "just fix them",
or when every live thread is an obvious nit: up to 4 threads per call, each
question titled `Thread 2/6 · CRITICAL · src/auth.py L45`.

## A5. Plan + reply per answered thread

Draft per P5; every sentence about code behaviour is checked against a file
read this turn (`file:line`), Greg's intent written as intent. Voice the batch
(P5.5). Per thread:

```
### Thread <n> · <SEVERITY> · [<path> (L<line>)](...)
Decision: <option>
Fix plan (Apply/Different): What · Where · Feasible: yes | needs-discussion | no — <why>
Suggested reply (English, paste-ready): <text block>
Optional suggestion block when one-click accept makes sense
```

Keep my code → reply only. Skip → one line why. Outdated but unresolved →
keep, mark `outdated`, lean on the thread URL.

## A6. Apply fixes

`Edit` per Apply/Different; non-trivial or cross-cutting → restate the plan
and confirm first. Then show `git diff`. No fixes at all → skip A6–A7.

## A7. Commit

Through `g-commit` (its popup; none in YOLO): scope from the touched paths and
`commitlint.config.js` (`git log --oneline -20` if unsure). "Tylko commit" →
"Committed, not pushed — say `pushed` (or `go`) once it's on the remote", wait.

## A8. Post replies once the fix is on the remote

After the push (or Greg's `pushed`/`go`/`ready`/`ok`/`done`), per P9.
Recommend **Yes** for Apply/Different and clean Keep replies, **No** for
outdated or empty ones. Once the decisions are made, a confirmation popup may
carry up to 4 replies.

- **Correcting a posted reply: edit it**, never a "Correction:" below:
  `gh api -X PATCH "repos/$OWNER/$REPO/pulls/comments/$MY_COMMENT_ID" -f
  body="$FIXED_BODY"`, voiced, the popup's first line saying it is an edit. A
  new reply only when someone answered below yours.
- **Review bodies without a thread** (bot summaries): ask once per session,
  **Issue comment** (`gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments" -X
  POST -f body=…`) or **Skip**.
- **Bot reviewers come back after every push** and may add threads that block
  the merge again. After the push start `gh-pr-checks-wait <n>` in the
  background; wait for the bot's check, then refetch `reviewThreads` with
  `isResolved:false`. Only an empty list allows "wątki zamknięte"; new ones →
  another round, the report counts rounds. A red check: `gh run view <id>
  --log-failed`, fix in a new commit. "Done" only when checks are green or the
  one blocker is `REVIEW_REQUIRED`.

## A9. After the loop

`Posted: N · Modified: M · Skipped: S`, `Outstanding: <count>`. Where Greg's
reply is last in a thread, resolve it: GraphQL `resolveReviewThread(input:
{threadId: "<node id>"})`; on error one line "resolve threads on GitHub
manually". Close with merge blockers: unresolved threads, ruleset flags
(`require_code_owner_review`, `required_review_thread_resolution`), CODEOWNERS
of the changed paths and who approved, red checks. Unattended tab: P10 mail,
`--subject 'PR #<n>: <N> replies posted, <S> skipped'`.

## Rules

- P11 applies. No commit or push without the A7 gate (skipped only in YOLO).
- Questions (A4) before plans and replies (A5).
- Never `gh pr review --approve/--request-changes/--comment`.
