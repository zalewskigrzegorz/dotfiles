---
name: g-pr-respond
description: Answer reviewers on YOUR OWN pull request. Fetches unresolved review threads and bot inline comments on a PR you authored, triages each by severity, asks per-thread in batched AskUserQuestion calls (≤4 at once, recommendation each), drafts English replies and fix plans, applies fixes, commits with g-commit style (you push), then posts thread replies one by one via gh. Never submits an APPROVE/REQUEST_CHANGES verdict — you can't review your own PR. Use whenever you want to respond to review feedback, answer reviewers, reply to review threads, or address comments on a PR you opened — current branch, PR number, or PR URL. If the PR is someone else's and you're the reviewer, use g-pr-review instead.
---

# g-pr-respond

Answer reviewers on a PR **you authored**. Single flow: fetch threads → triage → ask → fix → commit → you push → post replies. **Never** `gh pr review` — GitHub rejects self-approve anyway.

This is the author-side half of PR review. The reviewer-side half (leaving a fresh review on someone else's PR, or following up on one you already reviewed) lives in the sibling skill **`g-pr-review`**.

## When to use

The PR is **yours** and you want to deal with the feedback on it — reply to reviewers, apply their suggestions, push back, or work through unresolved threads. Target can be the **current branch**, a **PR number**, or a **PR URL**.

If it turns out the PR is someone else's, this is the wrong skill — see P2, which redirects you to `g-pr-review`.

## Language

Conversation can be in any language. **Anything posted to GitHub (thread replies, issue comments) must be English** — that's what reviewers and the author read. Explanations to the user can be in whatever language the user is using.

---

# Shared primitives

## P0. Local-first PR resolution (optimization, run first)

Goal: skip GitHub API calls we don't need. Comments/threads always go through `gh` (no local mirror exists), but diff + identity can come from the local git checkout when state matches remote.

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
| `USE_LOCAL=true`, `DIRTY` empty | Branch up-to-date with remote, clean worktree | **Use local git for diff/identity.** |
| `USE_LOCAL=true`, `DIRTY` non-empty | Up-to-date but uncommitted changes | Warn: "Worktree has uncommitted changes — replies/fixes assume the committed state. Continue?" Then proceed with local. |
| `USE_LOCAL=false`, branch exists, SHA mismatch | Remote moved (someone pushed) OR local moved (unpushed commits) | Warn explicitly: "Local HEAD `<short>` differs from `origin/<branch>` `<short>` — falling back to `gh` API so line links reflect what reviewers see on GitHub." |
| `USE_LOCAL=false`, no branch | User passed PR number/URL, not checked out | Silent fallback. |

State `USE_LOCAL=<true|false>` in one line in chat. The user can override ("trust local").

### P0b. Cache identity for the session

```bash
ME="${G_PR_ME:-$(gh api user --jq .login)}"
export G_PR_ME="$ME"
```

After first call in a session, subsequent runs read from env — saves one API hit per re-invocation.

---

## P1. Resolve the target

Capture `OWNER`, `REPO`, `NUMBER`, `SHA` (`headRefOid`), and the PR URL. Pass `-R "$OWNER/$REPO"` on every `gh` call when working from a PR URL or across forks.

**When `USE_LOCAL=true`**, derive locally and only call `gh pr view` for PR-side fields:

```bash
REPO_URL="$(git config --get remote.origin.url)"   # parse OWNER/REPO (git@ or https://)
SHA="$(git rev-parse HEAD)"
gh pr view --json number,url,author,baseRefName     # PR metadata not in local git
```

**Otherwise** (no checkout, or stale branch):

```bash
gh pr view --json number,url,title,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid,author
gh pr view <n> --json number,url,title,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid,author
# By URL: parse owner/repo/number from the URL, then -R owner/repo on every gh call
```

Cache for the session:

```bash
export G_PR_NUMBER="$NUMBER"
export G_PR_OWNER="$OWNER"
export G_PR_REPO="$REPO"
```

If no PR exists for HEAD and the user gave no number/URL → stop and ask for one.

## P2. Confirm it's your PR (guard)

This skill only handles PRs **you authored**. One authorship check settles it — being a co-author or having commits on the branch does **not** make it yours; only `author.login == me` does.

```bash
# true => my PR. Exit: 0 mine / 1 not mine / 2 no PR.
MINE="$(bash "$SCRIPTS/is-pr-mine.sh" "$NUMBER")"   # $NUMBER optional; omit to use current branch
echo "MINE=$MINE"
```

* `MINE=true` → proceed with the flow below.
* `MINE=false` → **wrong skill.** This PR is someone else's and you're the reviewer. Tell the user: "This is @author's PR, not yours — use `g-pr-review` to leave or follow up on a review." Stop unless the user explicitly overrides ("no, just draft author-style replies anyway").
* `MINE` empty / exit 2 → no PR resolved; go back to P1.

State `MINE=true` in one line before proceeding.

## P3. `AskUserQuestion` conventions

* **Batch up to 4 questions per call.** One question per thread, all four in the same `AskUserQuestion`. Never loop one-by-one when 2+ items are pending — that's the doubled-up feel to avoid.
* **Recommended option first**, with ` (Recommended)` appended to its label. Claude Code defaults to option 1.
* Each option's `description` carries the **why** and (where applicable) the exact reply body, so the user decides from the question alone — no code dumped in chat.
* Severity order: CRITICAL → HIGH → MEDIUM → LOW.

## P4. Cluster duplicates

Near-duplicate threads (same reviewer, same theme, same nit class — e.g. CodeRabbit firing five identical "missing `readonly`" hits) → cluster into **one** question with one shared reply, list the per-file links inside.

## P5. Comment writing rules

Write like a senior engineer leaving a quick reply, not like an AI assistant.

* **Lead with the point.** State the answer directly. No "Great catch!", "Good point", "I noticed that…", "It seems like…" preambles.
* **Concrete, not abstract.** Name the exact symbol/line/behavior. "Fixed — `user` was null on the empty-cart path, added a guard" beats "I have addressed the potential issue."
* **Show, don't describe.** If a change fits in a line or two, point at it or give the diff, not prose about it.
* **One issue per reply.** Don't bundle unrelated points.
* **Say why only when it's not obvious.** Skip rationale for trivial stuff. For real decisions, one short clause is enough.
* **No hedging, no filler.** Cut "I think", "maybe", "just", "simply", "in order to", "it's worth noting". No closing pleasantries ("Hope this helps!", "Let me know!").
* **Match length to weight.** Nit = one line. Real fix = 1–3 lines max.
* **No semicolons in prose.** New sentences, commas, or em dashes. Literal code may use `;`.
* Plain technical English. No emoji unless mirroring the reviewer's own.

## P5.5. Humanizer gate (mandatory)

P5 is how you write the first draft. The `humanizer` skill is the net that catches what still slips through — it's the dedicated AI-pattern remover, and replies here keep reading as machine-generated even after P5. So **every body bound for GitHub passes through the `humanizer` skill before the user sees it for confirmation**: thread replies, issue-comment bodies.

How to run it without burning the whole turn:

* **Load the `humanizer` skill once per run** (Skill tool), the first time you draft any GitHub-bound text. It stays loaded for the rest of the flow — don't re-invoke per comment.
* **Humanize per batch, not per comment.** Once you've drafted the ≤4 bodies for an `AskUserQuestion` batch, run all of them through the humanizer together, then put the *humanized* versions into the question. The user should only ever see post-humanizer text.
* **Technical mode — no soul injection.** Replies are reference/technical writing, so apply the humanizer's CONTENT PATTERNS (AI vocabulary, em-dash overuse, rule of three, vague attributions, filler, negative parallelisms, hedging) but **not** its PERSONALITY AND SOUL section. Don't add first person, opinions, jokes, or an "I genuinely…" voice — a clean, plain, senior-engineer note is the correct human voice here.
* **Don't re-humanize `Modify` text.** When Greg pastes a reply himself (A8b), it's already human — post it verbatim.

Why batch + technical mode: a per-comment full-skill pass on a 20-thread PR is slow, and it tempts the model to inflate a terse nit into a chatty paragraph — the opposite of what we want. A one-line reply that's already clean should come back as the same one line.

## P6. GitHub blob links

Every file reference uses a clickable blob link pinned to `SHA`:

```
[<path> (L<line>)](https://github.com/<OWNER>/<REPO>/blob/<SHA>/<path>#L<line>)
```

For a range, append `-L<endLine>`. When a comment is anchored to a GraphQL thread, also show the thread URL on its own line.

## P7. Scripts location

Bundled scripts live next to this skill:

```bash
SCRIPTS="${G_PR_RESPOND_SCRIPTS:-$HOME/.claude/skills/g-pr-respond/scripts}"
[[ -d "$SCRIPTS" ]] || SCRIPTS="$HOME/.cursor/skills/g-pr-respond/scripts"
```

* `fetch-comments.sh OWNER REPO NUMBER` — unresolved inline threads (GraphQL, paginated), enriched with `pr_author`, `last_comment_author`, `last_comment_at`, `author_replied_last`, `reviewer_followed_up`.
* `fetch-reviews.sh OWNER REPO NUMBER` — PR-level review bodies + merged top-level inline comments (humans + bots like CodeRabbit, Gemini, Copilot).
* `is-pr-mine.sh [NUMBER|URL]` — prints `true`/`false` for "am I the PR author" (context on stderr, exit 0 mine / 1 not / 2 no PR). No arg → current branch. Authoritative author check for P2.

## P8. Rate limits

`gh api` can hit secondary rate limits on large PRs with many bot reviews. On `403` with `secondary rate limit` in the body: wait ~30s, retry **once**. On second failure, surface the error and ask the user.

---

# The flow — answer reviewers on my PR

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
      1. Apply reviewer's suggestion — parameterized query (Recommended)
      2. Keep my code, reply explaining the validator already sanitizes
      3. Different approach — I'll describe
      4. Skip / already handled

Q2. Title: Thread 5/6 · LOW · src/user.controller.ts L88
    Prompt: @bob suggests `readonly` on injected services — taste. Keep current style?
    Options:
      1. Keep my code, reply explaining the module convention (Recommended)
      2. Apply reviewer's suggestion — add `readonly`
      3. Different approach — I'll describe
      4. Skip / already handled
```

Recommendation per thread (P3-default first):

| Recommend… | When |
|------------|------|
| `Apply reviewer's suggestion` | CRITICAL/HIGH + concrete bug, agreed fix, small/easy |
| `Keep my code, reply explaining` | Taste/style/nit, out-of-scope, existing code is right |
| `Different approach — I'll describe` | Valid concern, but reviewer's specific fix is wrong |
| `Skip / already handled` | Outdated, duplicate, done in a later commit |

## A5. After answers, emit plan + reply per thread

Draft each reply per P5, then run the batch through the humanizer (P5.5) before emitting. The reply shown here and posted in A8 is the humanized version.

For each answered thread, emit this block (drop sections that don't apply):

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

Pick `<scope>` from modified paths (e.g., `auth`, `api`, package name from repo's `commitlint.config.js`). For multi-area changes use the broadest sensible scope or omit. Match repo convention via `git log --oneline -20` if unsure.

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

Remind: **resolve threads on GitHub manually** — API replies don't auto-resolve.

---

# Things to avoid

* Never post a reply or comment without explicit Yes (batched or single).
* Never surface or post a GitHub-bound body that hasn't passed the humanizer (P5.5) — except `Modify` text Greg typed himself.
* Never commit before user confirms diff (A7).
* Never push — push is always the user's job.
* Never post anything in a language other than English on GitHub.
* Never emit per-thread fix plans or replies before asking the question (A4 before A5).
* Never repeat the summary table after first emission.
* Never use `--no-verify` to bypass hooks. If pre-commit fails, fix and create a new commit.
* **Never `gh pr review --approve` / `--request-changes` / `--comment`.** This is your own PR — GitHub rejects self-approve, and verdicts are the reviewer's job (that's `g-pr-review`). Per-thread replies use `.../comments/{id}/replies`.
* Never delete or edit existing comments on the PR.

---

# Troubleshooting

| Problem | What to do |
|---------|------------|
| `gh` not authenticated | `gh auth login` |
| No PR for current branch | Ask for PR number or URL |
| `MINE=false` (not my PR) | Wrong skill — switch to `g-pr-review` |
| Fork / ambiguous repo | Pass `-R owner/repo` from the PR URL |
| More than 100 threads | `fetch-comments.sh` paginates |
| `403` secondary rate limit | Wait ~30s, retry once; on second failure surface error |
| Reviewer already suggested code | Acknowledge their suggestion, don't duplicate the same diff |
| Pre-commit hook fails | Fix the issue, re-stage, **new** commit (never `--amend` after hook failure) |
| `422 ...line must be part of the diff` | Thread outdated against HEAD — for `.../replies` usually irrelevant; if not, modify or skip |
| Anchor mismatch (originalLine ≠ current) | Warn user, post reply anyway, link uses current SHA |
| Script errors | Ensure `bash`, `jq`, `gh` are installed |

---

# Internal checklist

* [ ] P0: `USE_LOCAL` resolved; `DIRTY` worktree warned if non-empty; mismatch surfaced explicitly
* [ ] P0: `$G_PR_ME` cached for the session
* [ ] P1: PR resolved (`OWNER`, `REPO`, `NUMBER`, `SHA`, URL)
* [ ] P2: `MINE=true` confirmed and stated; redirected to `g-pr-review` if false
* [ ] P3 batching applied (≤4 per `AskUserQuestion`, `(Recommended)` on default)
* [ ] P5 comment-writing rules followed; English only on GitHub
* [ ] P5.5 humanizer gate: every GitHub-bound body humanized (technical mode, batched); `Modify` text exempt
* [ ] P6 blob links pinned to `SHA`
* [ ] `fetch-comments.sh` + `fetch-reviews.sh` run
* [ ] Already-replied threads filtered; skipped count surfaced
* [ ] One summary table with `Rec` column
* [ ] A4 questions FIRST per batch, A5 plan/reply AFTER
* [ ] A6 fixes applied for `Apply` / `Different`; `git diff` shown; anchor mismatches warned
* [ ] A7 commit follows g-commit style; **no co-author, no AI footer**
* [ ] A8 batched post; final summary with Posted/Modified/Skipped + resolve reminder
* [ ] **No** `gh pr review` issued
