---
name: g-pr-review
description: Unified end-to-end PR workflow. Auto-detects whether the PR is mine (answer reviewers), someone else''s without my review yet (fresh review → APPROVE/REQUEST_CHANGES/COMMENT), or someone else''s where I already reviewed and the author replied (mixed: follow-up replies + optional updated verdict). Fetches unresolved threads and bot inline comments, asks per finding/thread in batched AskUserQuestion calls (≤4 at once, recommendation each), drafts English replies and fix plans, applies fixes, commits with g-commit style (user pushes), posts replies one by one via gh, then optionally finalizes a review verdict. Use whenever the user wants to review a PR, leave PR comments, approve/request changes, respond to PR feedback, or work through review threads — current branch, PR number, or PR URL.
---

# g-pr-review

End-to-end PR workflow. One skill, three flows, auto-selected from PR context.

## When to use

The user wants to do *anything* with PR review feedback on the **current branch**, a **PR number**, or a **PR URL** — leave a review on someone else''s PR, approve/request changes, respond to reviewers on their own PR, or handle follow-up comments after a previous review round.

## Language

Conversation can be in any language. **Anything posted to GitHub (review bodies, inline comments, thread replies, verdict summaries) must be English** — that''s what reviewers and authors read. Explanations to the user can be in whatever language the user is using.

---

# Shared primitives

These apply to every flow below.

## P0. Local-first PR resolution (optimization, run first)

Goal: skip GitHub API calls we don''t need. Comments/threads always go through `gh` (no local mirror exists), but diff + identity can come from the local git checkout when state matches remote.

### P0a. Detect working state

```bash
BRANCH="$(git branch --show-current 2>/dev/null || echo)"
DIRTY="$(git status --porcelain 2>/dev/null | head -1)"

if [[ -n "$BRANCH" ]]; then
  git fetch origin "$BRANCH" --quiet 2>/dev/null || true
  LOCAL_SHA="$(git rev-parse HEAD 2>/dev/null || echo)"
  REMOTE_SHA="$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo)"
  if [[ -n "$REMOTE_SHA" && "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
    USE_LOCAL=true
  else
    USE_LOCAL=false
  fi
else
  USE_LOCAL=false  # no branch (PR by number/URL, not checked out)
fi
```

| Signal | Meaning | Action |
|--------|---------|--------|
| `USE_LOCAL=true`, `DIRTY` empty | Branch up-to-date with remote, clean worktree | **Use local git for diff/identity. Skip `gh pr diff` in Flow B.** |
| `USE_LOCAL=true`, `DIRTY` non-empty | Up-to-date but uncommitted changes | Warn user: "Worktree has uncommitted changes — review/triage will use the committed state. Continue?" Then proceed with local. |
| `USE_LOCAL=false`, branch exists, SHA mismatch | Remote moved (someone pushed) OR local moved (unpushed commits) | Warn explicitly: "Local HEAD `<short>` differs from `origin/<branch>` `<short>` — falling back to `gh` API so review/triage reflects what reviewers see on GitHub." Use `gh pr diff` in Flow B. |
| `USE_LOCAL=false`, no branch | User passed PR number/URL, not checked out | Silent fallback — `gh pr diff` is the only option. |

State `USE_LOCAL=<true|false>` in one line in chat alongside the `MODE=` line from P2. The user can override ("force fresh API", "trust local").

### P0b. Cache identity for the session

```bash
ME="${G_PR_ME:-$(gh api user --jq .login)}"
export G_PR_ME="$ME"
```

After first call in a session, subsequent runs read from env — saves one API hit per re-invocation. Not a huge win on its own, but it''s free.

---

## P1. Resolve the target

Capture `OWNER`, `REPO`, `NUMBER`, `SHA` (`headRefOid`), and the PR URL. Pass `-R "$OWNER/$REPO"` on every `gh` call when working from a PR URL or across forks.

**When `USE_LOCAL=true` from P0**, derive locally and only call `gh pr view` for the PR-side fields (number, URL, author):

```bash
# Local-derived
REPO_URL="$(git config --get remote.origin.url)"
# Parse OWNER/REPO from REPO_URL (handles git@ and https://). SHA from rev-parse:
SHA="$(git rev-parse HEAD)"

# PR-side (one API call — number, url, author are PR metadata, not in local git)
gh pr view --json number,url,author,baseRefName
```

**Otherwise** (no checkout, or stale branch):

```bash
# Current branch with full metadata
gh pr view --json number,url,title,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid,author

# By number (add -R if ambiguous)
gh pr view <n> --json number,url,title,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid,author

# By URL: parse owner/repo/number from the URL, then -R owner/repo on every gh call
```

Cache for the session:

```bash
export G_PR_NUMBER="$NUMBER"
export G_PR_OWNER="$OWNER"
export G_PR_REPO="$REPO"
```

Re-invocations in the same shell reuse these instead of calling `gh pr view` again — invalidate when `git branch --show-current` no longer matches the cached PR''s head branch.

If no PR exists for HEAD and the user gave no number/URL → stop and ask for one.

## P2. Detect mode

This drives which flow to run. Done once, right after P1.

**First settle the only question that decides authorship: am I the PR author?** Use the helper — it prints a clean `true`/`false` (context on stderr) and is the source of truth. Having commits on the branch, or being a co-author, does **not** make it your PR — only `author.login == me` does.

```bash
# true => my PR, false => someone else''s. Exit: 0 mine / 1 not mine / 2 no PR.
MINE="$(bash "$SCRIPTS/is-pr-mine.sh" "$NUMBER")"   # $NUMBER optional; omit to use current branch

ME="${G_PR_ME:-$(gh api user --jq .login)}"  # cached from P0b
MY_REVIEWS="$(gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --jq "[.[] | select(.user.login == \"$ME\")] | length")"

if [[ "$MINE" == "true" ]]; then
  MODE=mine
elif [[ "$MY_REVIEWS" -gt 0 ]]; then
  MODE=mixed
else
  MODE=reviewing
fi
echo "MODE=$MODE (mine=$MINE, my_reviews=$MY_REVIEWS)"
```

State the detected mode in one line before proceeding, so the user knows which path we''re on. User override always wins ("just reply, no approve" → treat as `mine` flow; "do a fresh review" → treat as `reviewing` even if I have prior reviews).

| Mode | Meaning | Flow |
|------|---------|------|
| `mine` | PR author == me | **Flow A — Answer reviewers** (fetch threads → triage → fix → commit → post replies). Never `gh pr review` (GitHub rejects self-approve anyway). |
| `reviewing` | Someone else''s PR, no prior review from me | **Flow B — Fresh review** (analyze diff silently → per-finding Post/Skip → submit one APPROVE/REQUEST_CHANGES/COMMENT review). |
| `mixed` | Someone else''s PR, I already left ≥1 review | **Flow C — Follow-up** (handle threads where the author replied to me, optionally finalize an updated verdict). |

**Author vs contributor — don''t conflate them.** When `is-pr-mine.sh` says `false`, you are a **reviewer**, even if you pushed commits to the branch or co-authored the fix. In `reviewing`/`mixed` you never frame replies as the author "closing" threads: a thread opened by reviewer X and answered by the PR author is X''s to resolve — don''t jump in unless you have something to add. Reserve "answer reviewers / apply fix / commit" (Flow A) for `mine == true` only. If unsure, ask the user how they want to act (reviewer follow-up vs fresh review) before drafting anything.

## P3. `AskUserQuestion` conventions

* **Batch up to 4 questions per call.** One question per finding/thread/reply, all four in the same `AskUserQuestion`. Never loop one-by-one when 2+ items are pending — that''s the doubled-up feel to avoid.
* **Recommended option first**, with ` (Recommended)` appended to its label. Claude Code defaults to option 1.
* Each option''s `description` carries the **why** and (where applicable) the exact comment/reply body, so the user decides from the question alone — no code dumped in chat.
* Severity order: CRITICAL → HIGH → MEDIUM → LOW (or Critical → Suggestion → Nit for fresh reviews).

## P4. Cluster duplicates

Near-duplicate findings/threads (same reviewer, same theme, same nit class — e.g. CodeRabbit firing five identical "missing `readonly`" hits) → cluster into **one** question with one shared comment/reply, list the per-file links inside.

## P5. Comment writing rules

Write like a senior engineer leaving a quick review note, not like an AI assistant.

* **Lead with the point.** State the issue or ask directly. No "Great work!", "Good catch", "I noticed that…", "It seems like…", "Consider…" preambles.
* **Concrete, not abstract.** Name the exact symbol/line/behavior. "`user` can be null here → 401" beats "There might be a potential issue with null handling."
* **Show, don''t describe.** If a fix fits in a line or two, give a `suggestion` block or inline code instead of prose explaining it.
* **One issue per comment.** Don''t bundle unrelated points or pad with extra advice the reviewer didn''t ask about.
* **Say why only when it''s not obvious.** Skip rationale for trivial stuff. For real bugs, one short clause is enough ("…otherwise it throws on empty input").
* **No hedging, no filler.** Cut "I think", "maybe", "just", "simply", "in order to", "it''s worth noting". No closing pleasantries ("Hope this helps!", "Let me know!").
* **Match length to weight.** Nit = one line. Real bug = 1–3 lines max. Never a paragraph for a small thing.
* **No semicolons in prose.** New sentences, commas, or em dashes. Literal code may use `;`.
* Plain technical English. No emoji unless mirroring the reviewer''s own.

## P5.5. Humanizer gate (mandatory)

P5 is how you write the first draft. The `humanizer` skill is the net that catches what still slips through — it''s the dedicated AI-pattern remover, and review comments here keep reading as machine-generated even after P5. So **every body bound for GitHub passes through the `humanizer` skill before the user sees it for confirmation**: inline comments, thread replies, review summary bodies, verdict rationales. If it gets posted, it got humanized first — no exceptions.

How to run it without burning the whole turn:

* **Load the `humanizer` skill once per run** (Skill tool), the first time you draft any GitHub-bound text. It stays loaded for the rest of the flow — don''t re-invoke per comment.
* **Humanize per batch, not per comment.** Once you''ve drafted the ≤4 bodies for an `AskUserQuestion` batch, run all of them through the humanizer together, then put the *humanized* versions into the question. The user should only ever see post-humanizer text.
* **Technical mode — no soul injection.** PR comments are reference/technical writing, so apply the humanizer''s CONTENT PATTERNS (AI vocabulary, em-dash overuse, rule of three, vague attributions, filler, negative parallelisms, hedging) but **not** its PERSONALITY AND SOUL section. Don''t add first person, opinions, jokes, or an "I genuinely…" voice — a clean, plain, senior-engineer note is the correct human voice here. The humanizer itself says exactly this for technical text; hold it to that.
* **Don''t re-humanize `Modify` text.** When Greg pastes a reply himself (A8b), it''s already human — post it verbatim.

Why batch + technical mode: a per-comment full-skill pass on a 20-thread PR is slow, and it tempts the model to inflate a terse nit into a chatty paragraph — the opposite of what we want. The humanizer is here to strip slop, not add words. A one-line nit that''s already clean should come back as the same one line.

## P6. GitHub blob links

Every file reference uses a clickable blob link pinned to `SHA`:

```
[<path> (L<line>)](https://github.com/<OWNER>/<REPO>/blob/<SHA>/<path>#L<line>)
```

For a range, append `-L<endLine>`. When a comment is anchored to a GraphQL thread, also show the thread URL on its own line.

## P7. Scripts location

Bundled scripts live next to this skill:

```bash
SCRIPTS="${G_PR_REVIEW_SCRIPTS:-$HOME/.claude/skills/g-pr-review/scripts}"
[[ -d "$SCRIPTS" ]] || SCRIPTS="$HOME/.cursor/skills/g-pr-review/scripts"
```

* `fetch-comments.sh OWNER REPO NUMBER` — unresolved inline threads (GraphQL, paginated), enriched with `pr_author`, `last_comment_author`, `last_comment_at`, `author_replied_last`, `reviewer_followed_up`.
* `fetch-reviews.sh OWNER REPO NUMBER` — PR-level review bodies + merged top-level inline comments (humans + bots like CodeRabbit, Gemini, Copilot).
* `is-pr-mine.sh [NUMBER|URL]` — prints `true`/`false` for "am I the PR author" (context on stderr, exit 0 mine / 1 not / 2 no PR). No arg → current branch. Authoritative author check for P2.

## P8. Rate limits

`gh api` can hit secondary rate limits on large PRs with many bot reviews. On `403` with `secondary rate limit` in the body: wait ~30s, retry **once**. On second failure, surface the error and ask the user.

---

# Flow A — `MODE=mine` (answer reviewers on my PR)

End-to-end: fetch threads → triage → ask → fix → commit → user pushes → post replies. **Never** `gh pr review`.

## A1. Fetch threads + reviews

```bash
bash "$SCRIPTS/fetch-comments.sh" "$OWNER" "$REPO" "$NUMBER"  # unresolved threads
bash "$SCRIPTS/fetch-reviews.sh"  "$OWNER" "$REPO" "$NUMBER"  # PR-level review bodies + top-level inline
```

Each thread: `comments[]` flat. `comments[0]` = opening, `comments[-1]` = latest. Reply to `comments[-1].databaseId`.

### Filter live vs already-replied

* **Live** — `author_replied_last == false` OR `reviewer_followed_up == true`. Triage these.
* **Already replied** — `author_replied_last == true` AND `reviewer_followed_up == false`. Skip by default.

Surface the skipped count. If user asks "show already-replied", include with `Status: already-replied`.

## A2. Severity

| Severity | Signals | Default stance |
|----------|---------|----------------|
| **CRITICAL** | `🔒 Security`, `🚨 Critical`, `🔴 Critical`, clear security wording | Must-fix unless false positive |
| **HIGH** | `⚠️ Potential issue`, `🐛 Bug`, `⚡ Performance`, `🟠 Major` | Should fix |
| **MEDIUM** | `🛠️ Refactor suggestion`, `💡 Suggestion` | Recommended |
| **LOW** | `🧹 Nitpick`, `🔧 Optional`, `🟡 Minor`, `⚪ Info`, style/nit | Optional |

When a comment mixes a type label and a color badge, prefer the **badge/explicit severity**.

## A3. Summary table (emit once)

| # | Severity | Source | File:line | Author | Status | Rec | Summary |
|---|----------|--------|-----------|--------|--------|-----|---------|
| 1 | CRITICAL | inline | apps/api/src/auth.ts:17 | @alice | new | Apply | missing null guard |

* **Status**: `new` / `awaiting-you` (reviewer followed up) / `already-replied` (only when user asked).
* **Source**: `inline` / `review` / `issue`.
* **Rec**: option that will be marked default in A4.
* Cluster (P4) duplicate nits into one row.
* Below the table: `Skipped N already-replied thread(s) — say "show already-replied" to include them.` Omit if N == 0.

**Do NOT emit per-thread fix plans or replies here.** Those come after the user picks.

## A4. Batched questions (≤4 per call)

For each batch of up to 4 live threads, **one** `AskUserQuestion` call with 4 questions:

```
Q1. Title: Thread 2/6 · CRITICAL · src/auth.py L45
    Prompt: @alice flags SQL injection in raw query string. Apply her parameterized query?
    Options:
      1. Apply reviewer''s suggestion — parameterized query (Recommended)
      2. Keep my code, reply explaining the validator already sanitizes
      3. Different approach — I''ll describe
      4. Skip / already handled

Q2. Title: Thread 5/6 · LOW · src/user.controller.ts L88
    Prompt: @bob suggests `readonly` on injected services — taste. Keep current style?
    Options:
      1. Keep my code, reply explaining the module convention (Recommended)
      2. Apply reviewer''s suggestion — add `readonly`
      3. Different approach — I''ll describe
      4. Skip / already handled
```

Recommendation per thread (P3-default first):

| Recommend… | When |
|------------|------|
| `Apply reviewer''s suggestion` | CRITICAL/HIGH + concrete bug, agreed fix, small/easy |
| `Keep my code, reply explaining` | Taste/style/nit, out-of-scope, existing code is right |
| `Different approach — I''ll describe` | Valid concern, but reviewer''s specific fix is wrong |
| `Skip / already handled` | Outdated, duplicate, done in a later commit |

## A5. After answers, emit plan + reply per thread

Draft each reply per P5, then run the batch through the humanizer (P5.5) before emitting. The reply shown here and posted in A8 is the humanized version.

For each answered thread, emit this block (drop sections that don''t apply):

```
### Thread <n> · <SEVERITY> · [<path> (L<line>)](...)
Decision: <option label>

Fix plan (when Apply or Different):
- What: <one or two sentences>
- Where: [<path> (L<line>)](...)
- Feasible: yes | needs-discussion | no — <why>

Suggested reply (English, paste-ready):
` ` `text
<reply — no semicolons in prose>
` ` `

Optional — Suggested change (when one-click accept makes sense):
` ` `suggestion
<replacement lines>
` ` `
```

For `Keep my code` → reply only, no fix plan. For `Skip` → one line why, no reply, no fix.

Store internally per thread: `{thread_id, decision, reply_body, last_comment_databaseId, path, line, fix_required, suggestion_block}`.

For `isOutdated: true` threads — keep if still unresolved, mark `outdated` next to the line, lean on thread URL.

## A6. Apply fixes

For each `Apply` / `Different` with a concrete fix → `Edit` the file. Non-trivial / cross-cutting fixes: restate plan, confirm before editing.

After all edits: `git diff` → show.

### Anchor mismatch check

If `originalLine` (from the thread) differs from the current line by more than ~5, warn the user: "Thread anchored at L<original> but current code has it at L<actual>. Reply will still post; the line link uses current SHA."

## A7. Confirm + commit

Ask: "Diff looks good? Ready to commit (you push)?"

If yes, commit using **g-commit style** — conventional commits, lowercase imperative subject, one trailing gitmoji, single line by default, **no co-author trailer, no Generated-with-Claude footer**:

```bash
git add <changed files>
git commit -m "fix(<scope>): <subject> <gitmoji>"
```

Pick `<scope>` from modified paths (e.g., `auth`, `api`, package name from repo''s `commitlint.config.js`). For multi-area changes use the broadest sensible scope or omit. Match repo convention via `git log --oneline -20` if unsure.

If no fixes (everyone picked `Keep my code` / `Skip`), skip A6–A7.

Tell the user: "Committed. Push when ready, then say `pushed` (or `go`) to continue."

## A8. Wait for push, then post replies (batched)

Wait for: `pushed`, `go`, `ready`, `ok`, `done`.

Then batch up to 4 prepared replies per `AskUserQuestion` (per P3). Each question:

```
Title: Post reply <n>/<total> · <path>:<line> → @<reviewer>
Prompt: Post this reply?

<the full reply body — multi-line is fine>

Options:
  1. Yes — post it (Recommended)
  2. Modify — let me edit first
  3. No — skip this one
```

Recommendation per reply:

| Recommend… | When |
|------------|------|
| `Yes — post it` | Decision was `Apply` / `Different`, or a `Keep my code` reply that cleanly answers the reviewer |
| `No — skip this one` | Outdated/duplicate thread, or the reply adds nothing |

After the batch returns, post `Yes` ones via `gh api` (A8a) in order, handle any `Modify` (A8b), then next batch. **The `Yes` in the batch is the confirmation — no extra prompt.**

### A8a. Post via `gh api`

```bash
gh api "repos/$OWNER/$REPO/pulls/$NUMBER/comments/$COMMENT_ID/replies" \
  -X POST \
  -f body="$REPLY_BODY"
```

`$COMMENT_ID` = `databaseId` of `.comments[-1]` from `fetch-comments.sh`.

On success: `✅ Posted: <html_url>`.
On 422 / 404 / 403: print verbatim, ask user (retry / modify / skip). Never auto-retry except the P8 rate-limit case.

### A8b. If `Modify`

Plain prompt: "Paste the new reply text." Read the next user message as the body. Then post.

### A8c. PR-level review bodies (no thread to reply to)

When the source is `review` (bot summary, not an inline thread), no `comment_id` exists. Per session, ask once:

* **Issue comment** — `gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments" -X POST -f body="$REPLY_BODY"`
* **Skip** — note in summary.

### A8d. After the loop

```
Posted: <N>  ·  Modified: <M>  ·  Skipped: <S>
Outstanding (skipped + already-replied): <count>
```

Remind: **resolve threads on GitHub manually** — API replies don''t auto-resolve.

---

# Flow B — `MODE=reviewing` (fresh review on someone else''s PR)

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
* **options:** `Post` and `Skip`. Recommended first with ` (Recommended)`. Each option''s `description` = the **why** + the exact body that would be posted.

Recommend `Post` for Critical by default; judgment for Suggestion/Nit. Zero findings → skip to B4.

Before surfacing each batch, run the drafted `comment_body` values through the humanizer (P5.5). The body in the question is the humanized one — that''s what gets posted in B5. The verdict summary body (B4/B5) goes through the same gate.

## B4. Verdict

One `AskUserQuestion`, single question: `"<N> comments selected — submit review as?"`. Options:

* **Approve** — no blocking issues.
* **Request changes** — there are unaddressed Critical findings.
* **Comment only** — feedback without a verdict.
* **Don''t submit** — abort, post nothing.

Recommend **Request changes** if any Critical was selected; otherwise **Approve** (or **Comment only** when there are non-trivial Suggestions). Mark `(Recommended)`.

## B5. Submit (single call)

Map verdict → event: Approve→`APPROVE`, Request changes→`REQUEST_CHANGES`, Comment only→`COMMENT`, Don''t submit→abort.

Pipe JSON via stdin heredoc — **do not** write to a fixed temp path (collides with stale files):

```bash
gh api --method POST "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" --input - <<''JSON''
{
  "commit_id": "<SHA>",
  "event": "<EVENT>",
  "body": "<one- or two-line summary; include any findings that couldn''t be anchored inline>",
  "comments": [
    { "path": "<path>", "line": <line>, "side": "RIGHT", "body": "<comment_body>" }
  ]
}
JSON
```

If you genuinely need a file: `PAYLOAD=$(mktemp -t g-pr-review.XXXXXX.json)` — never a fixed `/tmp/g-pr-review.json`.

* Multi-line anchors: add `"start_line": <n>` alongside `"line"`.
* Empty `comments` is fine (clean approve / verdict-only).

Report the review URL (from `html_url` in the response). One line. Don''t re-print comments.

---

# Flow C — `MODE=mixed` (someone else''s PR, I already reviewed, author replied)

Hybrid: handle follow-up threads where the author addressed my comments, optionally update the verdict.

## C1. Fetch threads, filter to "follow-ups to me"

```bash
bash "$SCRIPTS/fetch-comments.sh" "$OWNER" "$REPO" "$NUMBER"
```

Treat as **live** any thread where:

* `last_comment_author == PR_AUTHOR` AND I was earlier in the thread (the author replied to my comment), OR
* `reviewer_followed_up == true` and the latest reviewer comment is mine and the author hasn''t answered yet — surface but recommend `Skip` (ball is in their court).

Plus: scan `fetch-reviews.sh` output for **new** findings from other reviewers since my last review — those go through Flow B logic if the user wants to add more comments.

## C2. Summary table

Same as A3, plus a column `Mine?` (`yes` if the thread''s opening comment is mine).

## C3. Batched questions per follow-up

Same as A4, but options shift:

| Option | When |
|--------|------|
| `Accept — author resolved it, post 👍 reply` | Author''s fix looks right (Recommended for clear resolutions) |
| `Push back — reply with counter-argument` | Author dismissed a valid concern |
| `Ask for clarification` | Author''s reply is ambiguous |
| `Skip` | Already resolved in spirit, no reply needed |

## C4. Post replies (batched)

Same as A8 — batched `AskUserQuestion`, post via `gh api .../comments/{id}/replies`. Drafted replies pass through the humanizer (P5.5) before the batch is surfaced.

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

* Never post a reply or comment without explicit Yes (batched or single).
* Never surface or post a GitHub-bound body that hasn''t passed the humanizer (P5.5) — except `Modify` text Greg typed himself.
* Never commit before user confirms diff (A7).
* Never push — push is always the user''s job.
* Never post anything in a language other than English on GitHub.
* Never emit per-thread fix plans or replies before asking the question (A4 before A5).
* Never repeat the summary table after first emission.
* Never use `--no-verify` to bypass hooks. If pre-commit fails, fix and create a new commit.
* When `MODE=mine`: never `gh pr review --approve` / `--request-changes` / `--comment`. GitHub rejects self-approve; per-thread replies use `.../comments/{id}/replies`.
* When `MODE=reviewing` or `mixed`: a finalizing `gh pr review` (via B5/C5) is allowed **only** after explicit Yes. Never finalize silently.
* Never delete or edit existing comments on the PR.
* Never write the review payload to a fixed temp path. Use stdin heredoc, or `mktemp` if a file is required.

---

# Troubleshooting

| Problem | What to do |
|---------|------------|
| `gh` not authenticated | `gh auth login` |
| No PR for current branch | Ask for PR number or URL |
| Fork / ambiguous repo | Pass `-R owner/repo` from the PR URL |
| More than 100 threads | `fetch-comments.sh` paginates |
| `403` secondary rate limit | Wait ~30s, retry once; on second failure surface error |
| Reviewer already suggested code | Acknowledge their suggestion, don''t duplicate the same diff |
| `422 pull_request_review_thread.line must be part of the diff` | Thread outdated against HEAD — for `.../replies` usually irrelevant; if not, modify or skip |
| Pre-commit hook fails | Fix the issue, re-stage, **new** commit (never `--amend` after hook failure) |
| `APPROVE` / `REQUEST_CHANGES` returns 422 | You''re the PR author — switch to `event: "COMMENT"` and tell the user |
| Script errors | Ensure `bash`, `jq`, `gh` are installed |
| Anchor mismatch (originalLine ≠ current) | Warn user, post reply anyway, link uses current SHA |

---

# Internal checklist

## Per run

* [ ] P0: `USE_LOCAL` resolved; `DIRTY` worktree warned if non-empty; mismatch (local ≠ origin) surfaced explicitly
* [ ] P0: `$G_PR_ME` cached for the session
* [ ] P1: PR resolved (`OWNER`, `REPO`, `NUMBER`, `SHA`, URL); cached in env when `USE_LOCAL=true`
* [ ] P2: `MODE` detected and stated in chat (`mine` / `reviewing` / `mixed`)
* [ ] P3 batching applied (≤4 per `AskUserQuestion`, `(Recommended)` on default option)
* [ ] P5 comment-writing rules followed; English only on GitHub
* [ ] P5.5 humanizer gate: every GitHub-bound body humanized (technical mode, batched) before surfacing; `Modify` text exempt
* [ ] P6 blob links pinned to `SHA`

## Flow A (`mine`)

* [ ] `fetch-comments.sh` + `fetch-reviews.sh` run
* [ ] Already-replied threads filtered; skipped count surfaced
* [ ] One summary table with `Rec` column
* [ ] A4 questions FIRST per batch, A5 plan/reply AFTER
* [ ] A6 fixes applied for `Apply` / `Different`; `git diff` shown; anchor mismatches warned
* [ ] A7 commit follows g-commit style; **no co-author, no AI footer**
* [ ] A8 batched post; final summary with Posted/Modified/Skipped + resolve reminder
* [ ] **No** `gh pr review` issued

## Flow B (`reviewing`)

* [ ] B1 diff source picked per P0 (`git diff merge-base..HEAD` when `USE_LOCAL=true`, else `gh pr diff`)
* [ ] Diff analyzed silently (no diff dump in chat)
* [ ] Findings recorded with severity, anchor, body, recommendation
* [ ] B3 batched per-finding questions with `(Recommended)`
* [ ] B4 verdict question with recommendation
* [ ] B5 submits via stdin heredoc, single `gh api` call
* [ ] Review URL reported

## Flow C (`mixed`)

* [ ] Follow-up threads (author replied to me) identified
* [ ] C3 batched questions with Accept/Push back/Ask/Skip
* [ ] C4 replies posted via batched flow
* [ ] C5 verdict offered (or skipped on user request)
