---
name: g-pr-triage
description: End-to-end PR review workflow. Fetches unresolved review threads + bot inline comments, asks per-thread upfront with an explicit recommendation, drafts English replies + fix plans, applies fixes, commits (you push), then posts replies one by one via gh after explicit Yes per comment. Use when the user wants to respond to or work through PR review comments on the current branch, a PR number, or a PR URL.
---

# g-pr-triage

## When to use

The user wants to work through open PR review feedback on the **current branch**, a **PR number**, or a **PR URL**. End-to-end: triage → ask → fix → commit → user pushes → post replies one by one with per-comment confirmation.

## Language

Conversation can be in any language (Polish, English, mixed). **Suggested replies posted to GitHub must always be in English** — those are the comments reviewers see on the PR. Explanations to the user can be in whatever language the user is using.

## Flow at a glance

1. Resolve PR
2. Fetch unresolved threads + review bodies
3. Severity classification + **one** summary table (whole queue)
4. **Per thread: question FIRST, plan AFTER.** `AskUserQuestion` with the recommended option marked, then draft fix/reply based on the choice.
5. Apply fixes for the threads marked `Apply` / `Different approach`
6. Show diff → user confirms
7. Skill commits (g-commit style — conventional commits + one trailing gitmoji)
8. User pushes
9. **Per reply: `AskUserQuestion` "Post? Yes / Modify / No".** Post to GitHub via `gh api .../comments/{id}/replies` after Yes.

Never commit or post silently. Never produce per-thread plans before asking the question.

## Output style rules

Mirror `g-pr-review` where applicable.

1. **No semicolons in prose** inside suggested replies. New sentences, commas, or em dashes. Literal code may use `;`.
2. **Clickable GitHub blob links** for every file reference:

   ```
   [<path> (L<line>)](https://github.com/<OWNER>/<REPO>/blob/<headRefOid>/<path>#L<line>)
   ```

   For a range, append `-L<endLine>`. When the comment is anchored to a GraphQL thread, also show the thread URL on its own line.
3. **Paste-ready replies** inside `` ```text `` fences (only the reply inside the fence).
4. **Small inline fixes** as GitHub `` ```suggestion `` blocks when one-click accept makes sense.
5. **Tone**: friendly, casual, professional. Light humor is fine when it fits.

---

## Step 1 — Resolve which PR

1. **Current branch** (default):

```bash
gh pr view --json number,url,title,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid
```

If no PR exists for `HEAD`, stop and ask for a number or URL.

2. **PR number:** `gh pr view <n> --json number,url,title,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid` (add `-R owner/repo` if ambiguous).

3. **PR URL:** parse `owner`, `repo`, `number`, then pass `-R owner/repo` on every `gh` call.

Capture `OWNER`, `REPO`, `NUMBER`, `headRefOid` (`SHA`), and the PR URL.

---

## Step 2 — Fetch all comment sources

Scripts live next to this skill: default **`$HOME/.claude/skills/g-pr-triage/scripts`**, fallback `$HOME/.cursor/skills/g-pr-triage/scripts`. Override with **`G_PR_TRIAGE_SCRIPTS`** if copied elsewhere.

```bash
TRIAGE_SCRIPTS="${G_PR_TRIAGE_SCRIPTS:-$HOME/.claude/skills/g-pr-triage/scripts}"
[[ -d "$TRIAGE_SCRIPTS" ]] || TRIAGE_SCRIPTS="$HOME/.cursor/skills/g-pr-triage/scripts"
```

### 2a. Unresolved inline threads (GraphQL, auto-paginated)

```bash
bash "$TRIAGE_SCRIPTS/fetch-comments.sh" "$OWNER" "$REPO" "$NUMBER"
```

JSON **array** of unresolved threads, sorted by `path` then line. Includes `isOutdated: true` ones — flag them in triage.

Each thread is enriched with:

- `pr_author` — PR author login.
- `last_comment_author`, `last_comment_at` — latest comment in the thread.
- `author_replied_last` — `true` when the **PR author** wrote the latest comment. Default stance: **skip** (likely already handled).
- `reviewer_followed_up` — `true` when a reviewer (anyone other than the PR author) wrote **after** the PR author's last reply. Ball is back in the PR author's court — treat as **live**, prioritize.

Each thread's `comments` is a flat array. `.comments[0]` = opening, `.comments[-1]` = latest. Each comment has `{id, databaseId, author:{login}, body, url, createdAt, path, line, originalLine, diffHunk}`. `databaseId` of the latest comment is what we'll reply to in Step 8.

### 2b. PR-level review bodies + merged inline comments

```bash
bash "$TRIAGE_SCRIPTS/fetch-reviews.sh" "$OWNER" "$REPO" "$NUMBER"
```

JSON object:

- **`reviews`** — non-empty PR review bodies (humans + bots like CodeRabbit, Gemini, Copilot).
- **`inline_comments`** — top-level inline comments, merged with extra originals fetched per-review when bot text says `Actionable comments posted: N` but the global list count is lower.

Cross-check coverage against GraphQL threads (by `path`, approximate line, author).

### 2c. General issue comments (only on request)

When the user asks for **all** comments including conversation:

```bash
gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments"
```

Link with `PR_URL#issuecomment-<id>`.

---

## Step 3 — Severity (order work CRITICAL → LOW)

| Severity | Typical signals | Default stance |
|----------|-----------------|----------------|
| **CRITICAL** | `_🔒 Security_`, `_🚨 Critical_`, `_🔴 Critical_`, clear security wording | Must-fix unless clearly false positive |
| **HIGH** | `_⚠️ Potential issue_`, `_🐛 Bug_`, `_⚡ Performance_`, `_🟠 Major_` | Should fix |
| **MEDIUM** | `_🛠️ Refactor suggestion_`, `_💡 Suggestion_` | Recommended |
| **LOW** | `_🧹 Nitpick_`, `_🔧 Optional_`, `_🟡 Minor_`, `_⚪ Info_`, style/nit | Optional |

When a comment mixes a **type** label and a **color** badge (suggestion vs major), prefer the **badge/explicit severity**.

---

## Step 4 — Triage + summary table (no per-thread output yet)

Internally classify each live thread:

- Severity (CRITICAL → LOW)
- Default recommendation: `Apply reviewer's suggestion` / `Keep my code, reply explaining` / `Different approach` / `Skip`
- Feasibility: `easy` / `needs-discussion` / `out-of-scope`

### Filter: skip already-answered threads

Split inline threads from `fetch-comments.sh` into:

- **Live** — `author_replied_last == false` OR `reviewer_followed_up == true`. Triage these.
- **Already replied** — `author_replied_last == true` AND `reviewer_followed_up == false`. Skip by default.

Surface skipped count in the summary. If user asks ("show me the ones I already answered"), include them with `Status: already-replied`.

### Emit the table once

| # | Severity | Source | File:line | Author | Status | Rec | Summary |
|---|----------|--------|-----------|--------|--------|-----|---------|
| 1 | CRITICAL | inline | apps/api/src/auth.ts:17 | @alice | new | Apply | missing null guard |

- **Status**: `new` (no prior author reply) / `awaiting-you` (reviewer followed up) / `already-replied` (only if user asked).
- **Source**: `inline` / `review` (PR-level body) / `issue`.
- **Rec**: the option that will be marked default in Step 5's question.
- Group obvious duplicate nits (same reviewer, same theme) into one **cluster** with one row.
- Below the table: `Skipped N already-replied thread(s) — say "show already-replied" to include them.` Omit if `N == 0`.

**Do NOT emit per-thread fix plans or suggested replies here.** Those come in Step 5 after the user picks an option.

---

## Step 5 — Per thread: question FIRST, plan AFTER

Iterate over live threads in severity order. For each thread (or cluster):

### 5a. Brief 1-line context

```
Thread <n>/<total> · <SEVERITY> · [<path> (L<line>)](https://github.com/<O>/<R>/blob/<SHA>/<path>#L<line>)
Reviewer: @<login> — <one-line summary>
Thread: <github thread url>
```

### 5b. `AskUserQuestion` — direction-first options with explicit recommendation

Options frame **which direction we go**, with the triage-recommended option **first** (keyboard default). Pick the recommended option per these heuristics:

| Recommend… | When |
|------------|------|
| `Apply reviewer's suggestion` | CRITICAL/HIGH + concrete bug, agreed fix, small/easy |
| `Keep my code, reply explaining` | Taste/style/nit, out-of-scope, the existing code is right |
| `Different approach — I'll describe` | Valid concern, but reviewer's specific fix is wrong/suboptimal |
| `Skip / already handled` | Outdated, duplicate, done in a later commit |

Concrete example (SQL injection, CRITICAL):

```
Title: Thread 2/6 · CRITICAL · src/auth.py L45
Prompt: @alice flags SQL injection in raw query string. Apply her parameterized query?
Options:
  1. Apply reviewer's suggestion — parameterized query  [recommended]
  2. Keep my code, reply explaining the validator already sanitizes
  3. Different approach — I'll describe
  4. Skip / already handled
```

Concrete example (style nit, LOW):

```
Title: Thread 5/6 · LOW · src/user.controller.ts L88
Prompt: @bob suggests `readonly` on injected services — taste. Keep current style?
Options:
  1. Keep my code, reply explaining the module convention  [recommended]
  2. Apply reviewer's suggestion — add `readonly`
  3. Different approach — I'll describe
  4. Skip / already handled
```

Rules:

- Recommended option **first** (Claude Code defaults to option 1).
- Near-duplicate threads → cluster into one question, one shared reply, per-file links.
- One `AskUserQuestion` per thread/cluster — emit the plan block (5c) before moving to the next question. Never loop silently.

### 5c. After the user picks, draft plan + reply (English)

Emit this block in chat. Drop sections that do not apply.

```
### Thread <n> · <SEVERITY> · [<path> (L<line>)](https://github.com/<O>/<R>/blob/<SHA>/<path>#L<line>)
Decision: <option label>

Fix plan (when Apply or Different):
- What: <one or two sentences>
- Where: [<path> (L<line>)](...)
- Feasible: yes | needs-discussion | no — <why>

Suggested reply (English, paste-ready):
\`\`\`text
<reply — no semicolons in prose>
\`\`\`

Optional — Suggested change (inline `suggestion` block, when one-click accept makes sense):
\`\`\`suggestion
<replacement lines>
\`\`\`
```

For `Keep my code` → no fix plan, only reply. For `Skip` → one line explaining why, no reply, no fix.

Internally store per thread: `{thread_id, decision, reply_body, last_comment_databaseId, path, line, fix_required, suggestion_block}` for Steps 6–8.

For **`isOutdated: true`** threads, keep them if still unresolved, mark `outdated` next to the line, lean on the thread URL.

---

## Step 6 — Apply fixes

For each thread where the decision is `Apply reviewer's suggestion` or `Different approach` with a concrete fix:

- Edit the file (use `Edit`).
- For non-trivial / cross-cutting fixes, restate the plan and confirm with the user before editing.

Skip threads with `Keep my code` or `Skip` — no file changes.

After all edits:

```bash
git diff
```

Show the diff.

---

## Step 7 — Confirm + commit

Ask the user: "Diff looks good? Ready to commit (you push)?"

If yes, stage and commit using **g-commit style** — conventional commits, lowercase imperative subject, one trailing gitmoji, single line by default, **no co-author trailer, no Generated-with-Claude footer**:

```bash
git add <changed files>
git commit -m "fix(<scope>): <subject> <gitmoji>"
```

Pick `<scope>` from modified paths (e.g., `auth`, `api`, package name from repo's `commitlint.config.js` if present). For multi-area changes use the broadest sensible scope or omit. Match the repo's existing scope convention — `git log --oneline -20` if unsure.

Single-line message by default. Only add a body if the change genuinely needs explanation (breaking change, migration note).

If there are no fixes (everyone picked `Keep my code` / `Skip`), skip Steps 6–7 entirely.

Tell the user: "Committed. Push when ready, then say `pushed` (or `go`) to continue."

---

## Step 8 — Wait for push, then post replies one by one

Wait for the user to confirm push (signals: `pushed`, `go`, `ready`, `ok`, `done`).

For each prepared reply (every thread where the decision was `Apply` / `Keep my code` / `Different`; skip `Skip`):

### 8a. `AskUserQuestion`

```
Title: Post reply <n>/<total> · <path>:<line> → @<reviewer>
Prompt: Post this reply?

<the full reply body — multi-line is fine>

Options:
  1. Yes — post it  [recommended]
  2. Modify — let me edit first
  3. No — skip this one
```

### 8b. If "Modify"

Ask for the new text. Either:
- `AskUserQuestion` with "Other" for short edits, OR
- Plain prompt: "Paste the new reply text" and read the next user message as the body.

Use the edited body for posting.

### 8c. Post via `gh api`

Reply to the existing thread by replying to the latest comment in the thread:

```bash
gh api "repos/$OWNER/$REPO/pulls/$NUMBER/comments/$COMMENT_ID/replies" \
  -X POST \
  -f body="$REPLY_BODY"
```

`$COMMENT_ID` = `databaseId` of the latest comment in that thread (`.comments[-1].databaseId` from `fetch-comments.sh`).

On success: `✅ Posted: <html_url-from-response>`.
On 422 / 404 / 403: print the error verbatim, ask user how to proceed (retry, modify, skip). Do **not** auto-retry.

### 8d. PR-level review bodies (no thread to reply to)

When the source is a `review` (bot summary, not an inline thread), there is no `comment_id` for `.../replies`. Two options, ask the user once per session if any exist:

- **Issue comment** — `gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments" -X POST -f body="$REPLY_BODY"` (posts as a top-level PR conversation comment).
- **Skip** — note in summary, user can post manually if wanted.

### 8e. After the loop

```
Posted: <N>  ·  Modified: <M>  ·  Skipped: <S>
Outstanding (skipped + already-replied): <count>
```

Remind the user to **resolve threads on GitHub** manually — the API replies don't auto-resolve.

---

## Things to avoid

- Never post without explicit per-comment Yes (Step 8a).
- Never commit before user confirms diff (Step 7).
- Never push — push is always the user's job.
- Never emit replies in any language other than English. The PR conversation is for reviewers, who read English.
- Never produce per-thread fix plans or replies before asking the question (Step 5b before 5c).
- Never repeat the summary table after the first emission.
- Never use `--no-verify` to bypass hooks. If a pre-commit hook fails, fix the underlying issue and create a new commit.
- Never `gh pr review --approve` / `--request-changes` / `--comment` — those finalize a review. Per-comment replies use `.../comments/{id}/replies`.
- Never delete or edit existing comments on the PR.

---

## Examples

### Keep my code (style nit)

User picks option 1 for thread 5/6 (`Keep my code, reply explaining`):

```
### Thread 5 · LOW · [apps/api/src/user.controller.ts (L88)](https://github.com/acme/api/blob/abc123/apps/api/src/user.controller.ts#L88)
Decision: Keep my code, reply explaining

Suggested reply (English, paste-ready):
\`\`\`text
Fair point. We keep constructor params without `readonly` in this module for consistency with the other controllers. Happy to do a follow-up PR that applies `readonly` everywhere at once.
\`\`\`
```

### Apply reviewer's suggestion (with inline `suggestion`)

User picks option 1 for thread 2/6 (`Apply reviewer's suggestion`):

```
### Thread 2 · HIGH · [apps/api/src/auth/guard.ts (L17)](https://github.com/acme/api/blob/abc123/apps/api/src/auth/guard.ts#L17)
Decision: Apply reviewer's suggestion

Fix plan:
- What: return 401 when `user` is nullish before reading `user.id`
- Where: [apps/api/src/auth/guard.ts (L17)](...)
- Feasible: yes — single guard

Suggested reply (English, paste-ready):
\`\`\`text
Good catch — added the null guard.
\`\`\`

Optional — Suggested change:
\`\`\`suggestion
    if (!user) throw new UnauthorizedException();
    return user.id === ctx.params.id;
\`\`\`
```

Then in Step 6, `Edit` the file to add the guard. Step 7 commits `fix(auth): guard nullish user before id check 🐛`. Step 8 posts "Good catch — added the null guard." as a reply to the thread.

---

## Troubleshooting

| Problem | What to do |
|---------|------------|
| `gh` not authenticated | `gh auth login` |
| No PR for current branch | Ask for PR number or URL |
| Fork / ambiguous repo | Pass `-R owner/repo` from the PR URL |
| More than 100 threads | `fetch-comments.sh` paginates until done |
| Reviewer already suggested code | Acknowledge their suggestion, don't duplicate the same diff |
| `422 pull_request_review_thread.line must be part of the diff` | Thread is outdated against current HEAD — for `.../replies` this usually doesn't matter, but if it does, modify or skip |
| Pre-commit hook fails | Fix the underlying issue, re-stage, **new** commit (never `--amend` after hook failure) |
| Script errors | Ensure `bash`, `jq`, `gh` are installed. Scripts use POSIX-friendly parsing |

---

## Internal checklist

- [ ] PR resolved (`OWNER`, `REPO`, `NUMBER`, `SHA`, PR URL)
- [ ] `fetch-comments.sh` run — unresolved threads with `author_replied_last` / `reviewer_followed_up` enrichment
- [ ] `fetch-reviews.sh` run — `reviews` + `inline_comments`
- [ ] Already-replied threads filtered out by default; count surfaced
- [ ] Severity + recommendation + feasibility per live thread
- [ ] **One** summary table before per-thread questions, with `Rec` column
- [ ] **Step 5**: `AskUserQuestion` FIRST per thread, plan/reply emitted AFTER (never plan-first)
- [ ] Options framed as `Apply reviewer's / Keep my code / Different / Skip` with recommendation as option 1
- [ ] Replies are English
- [ ] No semicolons in prose inside replies
- [ ] Step 6: fixes applied for `Apply` / `Different`; `git diff` shown
- [ ] Step 7: user confirms; commit follows g-commit style; **no co-author, no AI footer**
- [ ] Step 8: per-comment `AskUserQuestion` Yes/Modify/No; post via `gh api .../comments/{id}/replies`
- [ ] Final summary with Posted/Modified/Skipped counts + reminder to resolve threads on GitHub
