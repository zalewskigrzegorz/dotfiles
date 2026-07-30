---
name: g-pr-review
description: Review SOMEONE ELSE'S pull request as the reviewer. Two modes, auto-picked — a fresh review (analyze the diff → per-finding Post/Skip → submit one APPROVE/REQUEST_CHANGES/COMMENT verdict), or a follow-up when you already reviewed and the author replied (handle their responses, optionally update the verdict). Fetches unresolved threads and bot inline comments, asks per finding/thread in batched AskUserQuestion calls (≤4 at once, recommendation each), drafts English comments/replies, humanizes them, posts via gh. Use whenever you want to review a PR, leave PR comments, approve/request changes, or respond to the author on a PR you're reviewing — current branch, PR number, or PR URL. If the PR is YOURS and you're answering reviewers, use g-pr-respond instead.
---

# g-pr-review

Review a PR **you did not author**. Two flows, auto-selected: a fresh review, or a follow-up on one you already reviewed.

This is the reviewer-side half of PR review. The author-side half — answering reviewers on a PR **you** opened — lives in the sibling skill **`g-pr-respond`**.

## When to use

The PR is **someone else's** and you're acting as a reviewer — leave a fresh review, approve/request changes, or follow up on the author's replies to a review you already left. Target can be the **current branch**, a **PR number**, or a **PR URL**.

If it turns out the PR is yours, this is the wrong skill — see P2, which redirects you to `g-pr-respond`.

## Language

Conversation can be in any language. **Anything posted to GitHub (review bodies, inline comments, thread replies, verdict summaries) must be English** — that's what reviewers and authors read. Explanations to the user can be in whatever language the user is using.

---

# Shared primitives

Read `../g-pr-common/PRIMITIVES.md` now. It carries P0 (local-first
resolution + identity cache), P1 (target resolution), P3 (`AskUserQuestion`
conventions), P4 (duplicate clustering), P5 and P5.5 (comment rules and the
mandatory voice gate), P6 (blob links), P7 (scripts location) and P8 (rate
limits). Everything below assumes it.

P2 is NOT in that file — the ownership guard differs per flow, so it stays
here:

## P2. Guard + pick the flow

This skill only handles PRs **you did not author**. First settle authorship — being a co-author or having pushed commits does **not** make it yours; only `author.login == me` does.

```bash
# true => my PR, false => someone else's. Exit: 0 mine / 1 not mine / 2 no PR.
MINE="$(bash "$SCRIPTS/is-pr-mine.sh" "$NUMBER")"   # $NUMBER optional; omit to use current branch

ME="${G_PR_ME:-$(gh api user --jq .login)}"  # cached from P0b
MY_REVIEWS="$(gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --jq "[.[] | select(.user.login == \"$ME\")] | length")"
```

**Guard first:**

* `MINE=true` → **wrong skill.** This is your PR — answering reviewers is `g-pr-respond`'s job (and GitHub rejects self-approve). Tell the user: "This PR is yours — use `g-pr-respond` to answer reviewers." Stop unless the user explicitly overrides.
* `MINE=false` → proceed, then pick the flow by whether you already reviewed:

```bash
if [[ "$MY_REVIEWS" -gt 0 ]]; then
  MODE=followup   # Flow C
else
  MODE=fresh      # Flow B
fi
echo "MODE=$MODE (mine=$MINE, my_reviews=$MY_REVIEWS)"
```

State the detected mode in one line before proceeding. User override always wins ("do a fresh review" → treat as `fresh` even if I have prior reviews).

| Mode | Meaning | Flow |
|------|---------|------|
| `fresh` | Someone else's PR, no prior review from me | **Flow B — Fresh review** (analyze diff silently → per-finding Post/Skip → submit one APPROVE/REQUEST_CHANGES/COMMENT review). |
| `followup` | Someone else's PR, I already left ≥1 review | **Flow C — Follow-up** (handle threads where the author replied to me, optionally finalize an updated verdict). |

**You are the reviewer, not the author.** A thread opened by reviewer X and answered by the PR author is X's to resolve — don't jump in unless you have something to add. Never frame replies as the author "closing" threads. If you find yourself wanting to apply the fix + commit + reply as the author, you're in the wrong skill — that's `g-pr-respond`.

# Flow B — `MODE=fresh` (fresh review on someone else's PR)

Token-frugal: analyze silently, then ask compact batched questions. Never dump the diff or a long markdown report into chat — questions carry the context.

## B1. Get the diff

If `USE_LOCAL=true` from P0:

```bash
BASE_REF="$(gh pr view "$NUMBER" ${REPO_FLAG:+-R "$OWNER/$REPO"} --json baseRefName --jq .baseRefName)"
git fetch origin "$BASE_REF" --quiet 2>/dev/null || true
git diff "$(git merge-base HEAD "origin/$BASE_REF")"..HEAD
```

This is byte-equivalent to `gh pr diff` when the branch is up-to-date with remote, and skips one API hit (significant on large PRs where `gh pr diff` streams a multi-MB unified diff over REST).

Otherwise (`USE_LOCAL=false`):

```bash
gh pr diff "$NUMBER" ${REPO_FLAG:+-R "$OWNER/$REPO"}
```

## B2. Analyze silently

Categories — only surface things that genuinely matter:

* **Security:** injection (SQL/command/XSS), insecure deserialization, hardcoded secrets, weak authz/authn, IDOR.
* **Performance:** N+1, missing indexes, needless re-renders, memory leaks, blocking async, missing caching.
* **Quality:** DRY/SRP, deep nesting, magic values, naming, error handling, typing gaps.
* **Testing:** missing coverage for new behavior, non-asserting tests, flaky patterns, over-mocking.

Per finding, record: `severity` (Critical / Suggestion / Nit), `path`, `line`, one-line `title`, one-line `why`, exact `comment_body`, `recommended_action` (Post / Skip).

**Anchoring:** `line` must appear in the diff (right side for added/changed, `side: "LEFT"` for removed). If un-anchorable → fold into the review summary body instead of posting inline.

Cluster duplicates (P4).

## B3. Per-finding batched questions

`AskUserQuestion`, **batch up to 4** (P3). Per finding:

* **header:** severity (`Critical`, `Suggestion`, `Nit`).
* **question:** `<path>:<line> — <title>`.
* **options:** `Post` and `Skip`. Recommended first with ` (Recommended)`. Each option's `description` = the **why** + the exact body that would be posted.

Recommend `Post` for Critical by default; judgment for Suggestion/Nit. Zero findings → skip to B4.

Before surfacing each batch, run the drafted `comment_body` values through greg-voice (P5.5). The body in the question is the humanized one — that's what gets posted in B5. The verdict summary body (B4/B5) goes through the same gate.

## B4. Verdict

One `AskUserQuestion`, single question: `"<N> comments selected — submit review as?"`. Options:

* **Approve** — no blocking issues.
* **Request changes** — there are unaddressed Critical findings.
* **Comment only** — feedback without a verdict.
* **Don't submit** — abort, post nothing.

Recommend **Request changes** if any Critical was selected; otherwise **Approve** (or **Comment only** when there are non-trivial Suggestions). Mark `(Recommended)`.

## B5. Submit (single call)

Map verdict → event: Approve→`APPROVE`, Request changes→`REQUEST_CHANGES`, Comment only→`COMMENT`, Don't submit→abort.

Pipe JSON via stdin heredoc — **do not** write to a fixed temp path (collides with stale files):

```bash
gh api --method POST "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --input - <<'JSON'
{
  "commit_id": "<SHA>",
  "event": "<EVENT>",
  "body": "<one- or two-line summary; include any findings that couldn't be anchored inline>",
  "comments": [
    { "path": "<path>", "line": <line>, "side": "RIGHT", "body": "<comment_body>" }
  ]
}
JSON
```

If you genuinely need a file: `PAYLOAD=$(mktemp -t g-pr-review.XXXXXX.json)` — never a fixed `/tmp/g-pr-review.json`.

* Multi-line anchors: add `"start_line": <n>` alongside `"line"`.
* Empty `comments` is fine (clean approve / verdict-only).

Report the review URL (from `html_url` in the response). One line. Don't re-print comments.

---

# Flow C — `MODE=followup` (someone else's PR, I already reviewed, author replied)

Hybrid: handle follow-up threads where the author addressed my comments, optionally update the verdict.

## C1. Fetch threads, filter to "follow-ups to me"

```bash
bash "$SCRIPTS/fetch-comments.sh" "$OWNER" "$REPO" "$NUMBER"
```

Treat as **live** any thread where:

* `last_comment_author == PR_AUTHOR` AND I was earlier in the thread (the author replied to my comment), OR
* `reviewer_followed_up == true` and the latest reviewer comment is mine and the author hasn't answered yet — surface but recommend `Skip` (ball is in their court).

Plus: scan `fetch-reviews.sh` output for **new** findings from other reviewers since my last review — those go through Flow B logic if the user wants to add more comments.

## C2. Summary table

| # | Severity | Source | File:line | Author | Mine? | Status | Rec | Summary |
|---|----------|--------|-----------|--------|-------|--------|-----|---------|
| 1 | HIGH | inline | apps/api/src/auth.ts:17 | @alice | yes | awaiting-you | Accept | author added the guard |

* `Mine?` = `yes` if the thread's opening comment is mine.
* Cluster (P4) duplicates into one row.

## C3. Batched questions per follow-up

`AskUserQuestion`, batch up to 4 (P3). Options shift to the reviewer's stance:

| Option | When |
|--------|------|
| `Accept — author resolved it, post 👍 reply` | Author's fix looks right (Recommended for clear resolutions) |
| `Push back — reply with counter-argument` | Author dismissed a valid concern |
| `Ask for clarification` | Author's reply is ambiguous |
| `Skip` | Already resolved in spirit, no reply needed |

## C4. Post replies (batched)

Batched `AskUserQuestion` per prepared reply, then post via `gh api`. Drafted replies pass through greg-voice (P5.5) before the batch is surfaced.

```
Title: Post reply <n>/<total> · <path>:<line> → @<author>
Prompt: Post this reply?

<the full reply body — multi-line is fine>

Options:
  1. Yes — post it (Recommended)
  2. Modify — let me edit first
  3. No — skip this one
```

Post `Yes` ones via `gh api` in order; **the `Yes` is the confirmation — no extra prompt.**

```bash
gh api "repos/$OWNER/$REPO/pulls/$NUMBER/comments/$COMMENT_ID/replies" -X POST -f body="$REPLY_BODY"
```

`$COMMENT_ID` = `databaseId` of `.comments[-1]` from `fetch-comments.sh`. On success: `✅ Posted: <html_url>`. On 422/404/403: print verbatim, ask user (retry / modify / skip). If `Modify`: "Paste the new reply text", read next message as body, post verbatim (already human — no voice pass).

## C5. Optional updated verdict

After replies, one `AskUserQuestion`:

```
Title: Update review verdict for #<NUMBER>?
Prompt: Author addressed feedback. Submit an updated verdict?

Suggested: <APPROVE | REQUEST_CHANGES | COMMENT | Skip>
<one-line rationale>

Options:
  1. <recommended verdict> (Recommended)
  2. <next most likely>
  3. COMMENT — feedback only
  4. Skip — no new verdict
```

Recommendation:

| Recommend… | When |
|------------|------|
| `APPROVE` | All my prior Criticals resolved, only nits left |
| `REQUEST_CHANGES` | Unresolved Criticals remain |
| `COMMENT` | Mixed/uncertain |
| `Skip` | No material change since my last review |

If user picks a verdict, submit via B5 (single `gh api ... /reviews` call, `comments: []` if no new findings).

---

# Things to avoid

* Never post a comment or reply without explicit Yes (batched or single).
* Never surface or post a GitHub-bound body that has not passed greg-voice (P5.5) — except `Modify` text Greg typed himself.
* Never post anything in a language other than English on GitHub.
* A finalizing `gh pr review` (via B5/C5) is allowed **only** after explicit Yes. Never finalize silently.
* Never delete or edit existing comments on the PR.
* Never write the review payload to a fixed temp path. Use stdin heredoc, or `mktemp` if a file is required.
* **When `MINE=true`, stop and redirect to `g-pr-respond`.** This skill never applies the author's fix, commits, or answers reviewers as the author.
* Don't resolve threads that belong to another reviewer — a thread opened by X and answered by the author is X's to close.

---

# Troubleshooting

| Problem | What to do |
|---------|------------|
| `gh` not authenticated | `gh auth login` |
| No PR for current branch | Ask for PR number or URL |
| `MINE=true` (my own PR) | Wrong skill — switch to `g-pr-respond` |
| Fork / ambiguous repo | Pass `-R owner/repo` from the PR URL |
| More than 100 threads | `fetch-comments.sh` paginates |
| `403` secondary rate limit | Wait ~30s, retry once; on second failure surface error |
| Reviewer already suggested code | Acknowledge their suggestion, don't duplicate the same diff |
| `422 pull_request_review_thread.line must be part of the diff` | Thread outdated against HEAD — for `.../replies` usually irrelevant; if not, modify or skip |
| `APPROVE` / `REQUEST_CHANGES` returns 422 | You're the PR author — wrong skill, switch to `g-pr-respond` |
| Anchor mismatch (originalLine ≠ current) | Warn user, post reply anyway, link uses current SHA |
| Script errors | Ensure `bash`, `jq`, `gh` are installed |

---

# Internal checklist

## Per run

* [ ] P0: `USE_LOCAL` resolved; `DIRTY` worktree warned if non-empty; mismatch surfaced explicitly
* [ ] P0: `$G_PR_ME` cached for the session
* [ ] P1: PR resolved (`OWNER`, `REPO`, `NUMBER`, `SHA`, URL)
* [ ] P2: `MINE=false` confirmed; redirected to `g-pr-respond` if true; `MODE` (`fresh` / `followup`) detected and stated
* [ ] P3 batching applied (≤4 per `AskUserQuestion`, `(Recommended)` on default)
* [ ] P5 comment-writing rules followed; English only on GitHub
* [ ] P5.5 greg-voice gate: every GitHub-bound body voiced (full voice, batched); `Modify` text exempt
* [ ] P6 blob links pinned to `SHA`

## Flow B (`fresh`)

* [ ] B1 diff source picked per P0 (`git diff merge-base..HEAD` when `USE_LOCAL=true`, else `gh pr diff`)
* [ ] Diff analyzed silently (no diff dump in chat)
* [ ] Findings recorded with severity, anchor, body, recommendation
* [ ] B3 batched per-finding questions with `(Recommended)`
* [ ] B4 verdict question with recommendation
* [ ] B5 submits via stdin heredoc, single `gh api` call
* [ ] Review URL reported

## Flow C (`followup`)

* [ ] Follow-up threads (author replied to me) identified
* [ ] C2 summary table with `Mine?` column
* [ ] C3 batched questions with Accept/Push back/Ask/Skip
* [ ] C4 replies posted via batched flow
* [ ] C5 verdict offered (or skipped on user request)
