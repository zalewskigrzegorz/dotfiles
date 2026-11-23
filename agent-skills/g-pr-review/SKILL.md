---
name: g-pr-review
description: Review SOMEONE ELSE'S pull request as the reviewer. Fresh review (what/why summary + focus popup, voiced draft comments in tuicr, Greg sends them with :submit) or a follow-up after the author replied (answer threads, optionally update the verdict). Use to review a PR, leave PR comments, approve/request changes, or respond to the author on a PR you review — current branch, PR number or URL. Your own PR and answering reviewers → g-pr-respond.
---

# g-pr-review

Review a PR **you did not author**: a fresh review, or a follow-up on one you
already left. The author side is `g-pr-respond`.

Read `../g-pr-common/PRIMITIVES.md` now, once, with `Read` (language, P0–P12).
Everything below assumes it.

## P2. Guard + pick the flow

Only `author.login == me` makes a PR yours (co-authoring or pushing doesn't).
`$ME` comes from P0b, `$AUTHOR` from P1, no extra call.

```bash
[[ "$ME" == "$AUTHOR" ]] && MINE=true || MINE=false
MY_REVIEWS="$(gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --jq "[.[] | select(.user.login == \"$ME\")] | length")"
[[ "$MY_REVIEWS" -gt 0 ]] && MODE=followup || MODE=fresh
```

- `MINE=true` → wrong skill: "This PR is yours — use `g-pr-respond` to answer
  reviewers" (GitHub rejects self-approve too). Two overrides, each stated in
  one line first:
  - **Own-branch analysis** ("to mój branch, ale przejrzyj i przeanalizuj
    zmiany"): B1, B1.5, B2 only, nothing posted, no verdict. A large diff →
    Sonnet agents per package, count and model said first. Findings become
    fixes committed via `g-commit` plus a report in
    `~/Code/personal/bazgroly/<repo>/analysis/`; reviewers are answered later
    with `g-pr-respond`.
  - **Author away, fix on their branch** (the author is unreachable): after a
    normal Flow B, when Greg asks to apply the review himself. Push to their
    branch only after a popup. Seed the worktree first (`place-work-skills`,
    `copy-env-from-main.sh`), name a throwaway DB container with a session
    prefix (`<branch>-review-pg`) and remove it at the end; a stale
    `index.lock` → check running git processes and its mtime before removing.
    After the fixes offer `/loop babysit-prs` with an explicit end condition.
- `MINE=false` → `MODE=fresh` (Flow B) or `followup` (Flow C). State the mode
  in one line; Greg's override wins ("do a fresh review").

**You are the reviewer.** A thread opened by reviewer X and answered by the
author is X's to resolve. Never frame replies as the author closing threads;
applying fixes as the author is `g-pr-respond`.

# Flow B — fresh review

Analyse silently, hand the drafts over in tuicr. Never dump the diff or a long
report into chat.

## B1. Get the diff

`gh pr view "$NUMBER" --json changedFiles --jq .changedFiles`. Over 300 files
GitHub refuses the diff (406 `too_large`): skip B3, use the popup flow from
the `g-pr-review-popups` tag (one popup per draft from Critical down, one
review after the verdict).

```bash
# USE_LOCAL=true
BASE_REF="$(gh pr view "$NUMBER" ${REPO_FLAG:+-R "$OWNER/$REPO"} --json baseRefName --jq .baseRefName)"
git fetch origin "$BASE_REF" --quiet 2>/dev/null || true
rtk proxy git diff "origin/$BASE_REF"...HEAD > <scratch>/pr.diff   # three dots = merge-base diff
# USE_LOCAL=false
gh pr diff "$NUMBER" ${REPO_FLAG:+-R "$OWNER/$REPO"}
```

Read the diff from the file; the rtk filter truncates it otherwise.

## B1.5. Orient, then let Greg aim the review

Read the body (`gh pr view --json body`) and the diff once. Print in his
language, **≤10 lines**: **Cel** (what and why, epic link if any), **Co robi**
(2–5 concrete points: hook / endpoint / flag names), **Skala + flagi** (files,
`+/−`, areas, what bites at merge: conflict, draft, red CI, migrations, flags).

Then one `AskUserQuestion`, `multiSelect: true`, header `Fokus`, "Na co review
ma zwrócić szczególną uwagę?": `Standardowy pełny przegląd (Recommended)` plus
2–3 risky areas from the summary, each label naming the spot, the description
saying why. Picked areas (and free text) are B2's priority: dig first, follow
call sites beyond the diff, and each ends in a finding or an explicit "checked,
clean" line in B4. Skip the popup for a trivial PR (≤3 files, one change) or
when the prompt says `Fokus: standard` (an unattended `workctl` tab); the
summary still prints.

**Pending reviews of mine on linked PRs** (pitch, design, parent): one stuck in
`PENDING` once decided a PR's direction unseen. Show it in a popup with the
comments in `preview` (send / leave / delete) before the findings:

```bash
gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviews(first:20,states:PENDING){nodes{author{login} comments(first:20){nodes{path line body}}}}}}}' -F o="$OWNER" -F r="$REPO" -F n=<linked-pr>
```

**Red CI: this PR or its base?** `gh run list --branch "$BASE_REF" --workflow
<wf> --limit 1 --json conclusion,url`. Same job red on base → "red z base, poza
zakresem review", move on. A job log: `rtk proxy gh run view <run> --job <id>
--log > <scratch>/job.log`, then `rg -F '##[error]'` (`--log-failed | tail`
came back cut).

## B2. Analyse silently

Only what matters: **Security** (injection, deserialization, secrets, weak
authz/authn, IDOR), **Performance** (N+1, missing indexes, re-renders, leaks,
blocking async, caching), **Quality** (DRY/SRP, nesting, magic values, naming,
error handling, typing), **Testing** (missing coverage, non-asserting, flaky,
over-mocking).

- A finding hinging on a dependency: `ls <worktree>/node_modules/<pkg>`;
  missing → `cd <scratch> && npm pack <pkg>@<lockfile version> && tar -xzf
  <pkg>-*.tgz`, read `package/dist` (no `realpath` loop).
- **Check every finding against the code and the body before voicing it**,
  subagent findings included; "checked / not checked" in the `description`.
- Per finding: severity (Critical / Suggestion / Nit), `path`, `line`, title,
  why, `comment_body`, Post/Skip.
- **Anchor**: `line` must be in the diff (right side; `LEFT` for removed).
  Un-anchorable → review-level comment. Cluster duplicates (P4).

## B3. Open tuicr on its own workspace

Greg reviews in **tuicr**: he reads, edits or deletes the drafts and sends
himself. The popup flow lives at tag `g-pr-review-popups` (`git checkout
g-pr-review-popups -- agent-skills/g-pr-review`). A tuicr PR session exists
only once the TUI opened it, so the split comes first. In the background
(`run_in_background`, returns when Greg quits tuicr):

```bash
tuicr-split "$(git rev-parse --show-toplevel 2>/dev/null || pwd)" pr "$NUMBER" --repo-url "https://github.com/$OWNER/$REPO"
tuios wait-for window-output -w <id> --pattern 'PR Mode' --timeout 60000 >/dev/null   # <id> from the first line, window=<id>
SLUG="gh:$OWNER/$REPO/pr/$NUMBER"
tuicr review list --repo "$OWNER/$REPO" | jq -e --arg s "$SLUG" '.[] | select(.slug == $s and .active)' >/dev/null
```

Sessions are per PR: a second PR needs its own `tuicr-split`, and check
`tuicr review list --all` before any `review add`. `tuicr-split` opens a
`tuicr` workspace (first empty after the agent's, never a split) and mails
Greg's Inbox the number. No `TUIOS_PANE_ID` or `tuicr-split` fails → one line,
popup flow from the tag.

## B4. Drop the drafts in

Voice every `comment_body` in one batch (P5.5), then per finding (Critical →
`issue`, Suggestion → `suggestion`, Nit → `nit`, a question → `note`):

```bash
tuicr review add --session "$SLUG" --username Wintermute --type issue \
  --target-file <path> --line <line> [--end-line <n>] --side new "<comment_body>"
```

`--side old` for removed lines; review-level → omit `--target-file`; clustered
duplicates → one comment.

- A finding that changes who has access or which path runs gets a ```` ```mermaid ````
  flowchart between description and request; the chat verdict opens with
  "before: X, after: Y", no symbol names. "Dodaj graf" = a diagram in the PR
  comment, never ASCII in chat.
- **Verify every anchor**: a comment outside the diff is stored, exits 0 and
  never renders. After the last add `tuicr review comments --session "$SLUG"`,
  check each `start_line` against the hunks; a miss → `tuicr review delete
  --session "$SLUG" --comment-id <id>`, re-add at the nearest changed line or
  review-level.
- Zero findings → no drafts, the split still opens for Greg to approve.

End the turn in ≤3 lines, no popup:

- the verdict you'd pick and why: **Request changes** with any `issue`,
  **Approve** with only nits or nothing, **Comment** with real suggestions.
  Red CI from the diff is never Approve; red CI proven unrelated (same job red
  on `main`, no overlap with `git diff --name-only origin/main...HEAD`) + zero
  findings → Approve with one review-level sentence naming those checks;
- `N szkiców w tuicr, workspace <k>. Szkic jest lokalny, na GitHubie dopiero po
  :submit, poleci pod Twoim kontem. W diffie m/M skok do szkicu, dd usuwa, c
  dodaje. :summary to tylko lista, Enter skacze do kodu.` Keys:
  `references/tuicr-keys.md`.

Greg's `:submit` picks Comment / Approve / Request changes / Draft. The summary
stays empty unless he writes one.

## B5. Read what went out

When `tuicr-split` returns:

```bash
tuicr review comments --session "$SLUG" 2>/dev/null | jq -c '.[] | {author, lifecycle_state, location, content}'
gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --jq "[.[] | select(.user.login == \"$ME\")] | last | {state, html_url, submitted_at}"
```

- New review of mine → one line: state + `html_url`, then B6 (`APPROVED`
  counts as `APPROVE`).
- No review, drafts still `local_draft` → "nic nie poszło, szkice zostały w
  sesji `$SLUG`"; `tuicr-split` again on his word.
- Session gone, no review → he deleted everything: one line, then B6.

Never `:submit` for him, never send drafts via the API instead. A 5xx on
`:submit`: read `reviews`, "nic nie poszło, `<code>`", he repeats `:submit`.
API sending only with 0 drafts left and after his word.

## B6. Close the review worktree

Only when all hold: toplevel under `~/Code/tree/wt-*`, current branch = PR
head, `git status --porcelain` empty, nothing committed or pushed here (the
author-away override keeps its tree). Any check fails → say nothing.

- **`APPROVE` submitted** → the URL line ends with "zamykam worktree", and
  `workctl rm --self` is the **last tool call** (it kills this session).
- **Anything else** → one line "worktree zostaje, zamkniesz `prefix+X`".
- **Unattended tab (P10)** → one popup **Zamknij worktree** (Recommended) /
  **Zostaw**, verdict in its question. Zamknij → same call. Zostaw or a failed
  check → the P10 mail. APPROVE closes with no mail.

Never `--force`; "has uncommitted changes" → one line, tree stays.

# Flow C — follow-up (I already reviewed, author replied)

## C1. Threads that follow up on me

`bash "$SCRIPTS/fetch-comments.sh" "$OWNER" "$REPO" "$NUMBER"`. Live:

- `last_comment_author == PR_AUTHOR` and I was earlier in the thread, or
- `reviewer_followed_up == true`, latest reviewer comment mine, author silent
  → surface but recommend Skip.

New findings from other reviewers since my last review (`fetch-reviews.sh`) go
through Flow B logic if Greg wants to add comments.

## C2. Summary table

| # | Severity | Source | File:line | Author | Mine? | Status | Rec | Summary |
|---|---|---|---|---|---|---|---|---|

`Mine?` = the thread's opening comment is mine. Cluster per P4.

## C3. One popup per thread (P3)

**Accept** — author resolved it, post 👍 (Recommended for clear fixes) ·
**Push back** — dismissed a valid concern · **Ask for clarification** —
ambiguous reply · **Skip** — resolved in spirit.

## C4. Post replies

Voice the drafts (P5.5), then post per P9. `headRefOid` differs from the sha
the draft was written against → `gh api repos/$OWNER/$REPO/compare/<old>...<new>`
first; a changed text goes through greg-voice and back to Greg. An `APPROVE`
on a newer sha with changes in the drafted files needs his "kk".

## C5. Optional updated verdict

One popup, recommended first: **APPROVE** (all my Criticals resolved, nits
left) · **REQUEST_CHANGES** (Criticals remain) · **COMMENT** (mixed, and at
least one new inline comment; otherwise not offered) · **Skip** (no material
change, or only thread replies this round). "Robimy approve" after reading the
author's answer = bare `APPROVE`, empty body. Submit via C6, then B6.

## C6. Submit via the API (Flow C only)

Two calls, never one: a review created with `event` makes `body` mandatory for
`REQUEST_CHANGES`/`COMMENT`, which puts a "see inline comments" blob on the PR.

```bash
REVIEW_ID=$(gh api --method POST "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --input - <<'JSON' | jq -r .id
{ "commit_id": "<SHA>", "comments": [ { "path": "<path>", "line": <line>, "side": "RIGHT", "body": "<comment_body>" } ] }
JSON
)
gh api --method POST "repos/$OWNER/$REPO/pulls/$NUMBER/reviews/$REVIEW_ID/events" -f event=<APPROVE|REQUEST_CHANGES|COMMENT>
```

- **Body always empty.** Exceptions: an un-anchorable finding (`-f body=…` on
  step 2), and `REQUEST_CHANGES` with zero inline comments, which takes a
  one-line body naming the open thread (else 422 `You need to leave a
  comment…`). Empty `comments` works for `APPROVE` only; never offer
  `COMMENT` with zero comments.
- Step 2 fails → delete the pending review: `gh api -X DELETE
  "repos/$OWNER/$REPO/pulls/$NUMBER/reviews/$REVIEW_ID"`.
- Payload via stdin heredoc; a file only via `mktemp -t g-pr-review.XXXXXX.json`,
  never a fixed `/tmp` path. Multi-line anchors: `"start_line"` next to `"line"`.
- Report `html_url` in one line, don't re-print comments. Then B6.

# Rules

- P11 applies. In Flow B Greg's `:submit` is the only send; C6 only after
  his explicit Yes.
- `MINE=true` → stop and redirect; never apply the author's fix or answer as
  the author. `APPROVE`/`REQUEST_CHANGES` returning 422 means the same.
- Never resolve another reviewer's thread.

## Running the PR's tests locally

A fresh review worktree has no built packages: vitest dies on `Failed to
resolve import "@<org>/shared"`. Precheck `test -d packages/shared/dist ||
echo unbuilt`; unbuilt → "unit nie puszczone lokalnie, paczki niezbudowane
(~3–6 min)", build only when the risk is worth it. One file from
`apps/<app>`: `pnpm exec vitest run <file>`.
