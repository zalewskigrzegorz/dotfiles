---
name: g-pr-triage
description: Fetches unresolved PR review threads and bot inline comments via GraphQL, classifies by severity/action, asks per-thread with paste-ready replies and fix plans. Use when the user wants to respond to or work through PR review comments on current branch, PR number, or PR URL.
---

# g-pr-triage

## When to use

The user wants to work through open PR review feedback on the **current branch**, a **PR number**, or a **PR URL**. The skill **prepares** replies and fix plans only. The user pastes replies and applies fixes themselves. Nothing is posted or edited automatically.

## Language

All analysis, fix plans, and suggested replies are **English**, even if the conversation is in another language.

## Constraints (prepare-only by default)

- Do **not** run `gh pr review`, `gh pr comment`, `gh api ... -X POST/PATCH/DELETE`, or any write call against GitHub **by default**.
- Do **not** edit source files, run `git commit`, or push.
- Output is for manual copy-paste and manual fixes. Posting or applying later is a separate step.

### Opt-in exception: pending draft review

The user can explicitly opt in to submitting the prepared replies as a **PENDING** GitHub review (a draft that the user submits manually from the GitHub UI). Triggers:

- Polish: "wrzuć jako draft", "zrób draft review", "wrzuć do draftu".
- English: "submit as pending review", "post as draft", "draft this review on GitHub".

When opted in, follow **Step 8 — Submit as pending draft review** below. Without an explicit opt-in, never write to GitHub.

## Output style rules

Mirror `g-pr-review` where applicable.

1. **No semicolons in prose** inside suggested replies or plan text. Use new sentences, commas, or em dashes. Literal code may use `;`.
2. **Clickable GitHub blob links** for every file reference (Claude Code does not resolve workspace-relative paths the way Cursor did). Format:

   ```
   [<path> (L<line>)](https://github.com/<OWNER>/<REPO>/blob/<headRefOid>/<path>#L<line>)
   ```

   For a range, append `-L<endLine>` to the anchor. Example:
   `[apps/api/src/foo.ts (L42)](https://github.com/acme/api/blob/abc123/apps/api/src/foo.ts#L42)`.
   When the comment is anchored to a GraphQL **thread**, also show the thread URL on its own line — both links coexist.
3. **Paste-ready replies** inside a fenced block: `` ```text `` — only the reply inside the fence.
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

3. **PR URL:** parse `owner`, `repo`, `number`, then use `-R owner/repo` on every `gh` call.

Capture `OWNER`, `REPO`, `NUMBER`, `headRefOid`, and the PR URL.

---

## Step 2 — Fetch all comment sources

Scripts live next to this skill: `scripts/` under the skill directory (default **`$HOME/.claude/skills/g-pr-triage/scripts`**, with `$HOME/.cursor/skills/g-pr-triage/scripts` as fallback). Override with **`G_PR_TRIAGE_SCRIPTS`** if the skill is copied elsewhere.

```bash
TRIAGE_SCRIPTS="${G_PR_TRIAGE_SCRIPTS:-$HOME/.claude/skills/g-pr-triage/scripts}"
[[ -d "$TRIAGE_SCRIPTS" ]] || TRIAGE_SCRIPTS="$HOME/.cursor/skills/g-pr-triage/scripts"
```

### 2a. Unresolved inline threads (GraphQL, auto-paginated)

```bash
bash "$TRIAGE_SCRIPTS/fetch-comments.sh" "$OWNER" "$REPO" "$NUMBER"
```

JSON **array** of unresolved threads, sorted by `path` then line. Include threads with `isOutdated: true` but flag them in triage.

Each thread is enriched with:

- `pr_author` — PR author login.
- `last_comment_author`, `last_comment_at` — latest comment in the thread.
- `author_replied_last` — `true` when the **PR author** wrote the latest comment. Default stance: **skip** (likely already handled). Surface only in the summary count.
- `reviewer_followed_up` — `true` when a reviewer (anyone other than the PR author) wrote **after** the PR author's last reply. The ball is back in the PR author's court — treat as **live**, prioritize.

Each thread's `comments` is a **flat array** (sorted by `createdAt` is not guaranteed — sort yourself if order matters). Use `.comments[0]` for the opening comment, `.comments[-1]` for the latest, `.comments | length` for the count. Each comment has `{id, databaseId, author:{login}, body, url, createdAt, path, line, originalLine, diffHunk}`.

### 2b. PR-level review bodies + merged inline comments

```bash
bash "$TRIAGE_SCRIPTS/fetch-reviews.sh" "$OWNER" "$REPO" "$NUMBER"
```

JSON object:

- **`reviews`** — non-empty PR review bodies (humans and bots such as CodeRabbit, Gemini, Copilot).
- **`inline_comments`** — top-level inline comments from the PR, merged with any extra originals fetched per-review when bot text says `Actionable comments posted: N` but the global list count is lower (avoids missing bot threads).

Use **`reviews`** for full bot summaries and anything that only appears as a review body. Use **`inline_comments`** to cross-check coverage against GraphQL threads (by `path`, approximate line, author).

### 2c. General issue comments (only on request)

When the user asks for **all** comments including conversation:

```bash
gh api "repos/$OWNER/$REPO/issues/$NUMBER/comments"
```

These have no `path`/`line`. Link with `PR_URL#issuecomment-<id>`.

---

## Step 3 — Severity (order work CRITICAL → LOW)

| Severity | Typical signals | Default stance |
|----------|-----------------|----------------|
| **CRITICAL** | `_🔒 Security_`, `_🚨 Critical_`, `_🔴 Critical_`, clear security / vulnerability wording | Treat as must-fix unless clearly false positive |
| **HIGH** | `_⚠️ Potential issue_`, `_🐛 Bug_`, `_⚡ Performance_`, `_🟠 Major_` | Should fix |
| **MEDIUM** | `_🛠️ Refactor suggestion_`, `_💡 Suggestion_` | Recommended |
| **LOW** | `_🧹 Nitpick_`, `_🔧 Optional_`, `_🟡 Minor_`, `_⚪ Info_`, style / nit | Optional |

If a comment mixes a **type** label and a **color** badge (e.g. suggestion vs major), prefer the **badge / explicit severity** for classification.

---

## Step 4 — Triage each thread

| Recommendation | When |
|----------------|------|
| `fix` | Concrete bug, wrong type, missing guard, broken test — small and agreed |
| `reply` | Taste, style, out-of-scope, question, or you disagree — words not code |
| `both` | Valid issue plus a question, or non-trivial fix that needs a short explanation |
| `skip` | Already fixed in a later commit, duplicate thread, or obsolete |

**Feasibility** for `fix` / `both`: `easy` · `needs-discussion` · `out-of-scope`.

Keep fix plans short: **what**, **where** (linked files), **feasible?**, up to two **alternatives** if there is a real trade-off.

### Filter: skip already-answered threads

Before building the queue, split inline threads from `fetch-comments.sh` into:

- **Live** — `author_replied_last == false` OR `reviewer_followed_up == true`. These are the threads to triage.
- **Already replied** — `author_replied_last == true` AND `reviewer_followed_up == false`. The PR author wrote the last word and the reviewer has not pushed back. Skip by default — do **not** prepare a reply.

Default: only triage **Live** threads. Show the count of skipped ones in the summary so the user knows they exist. If the user explicitly asks to revisit them (e.g. "show me the ones I already answered"), include them with `Status: already-replied`.

### Summary table before per-thread questions

Show one table so the user sees the whole queue first:

| # | Severity | Source | File:line | Author | Status | Summary |
|---|----------|--------|-----------|--------|--------|---------|
| 1 | … | inline / review body / issue | … | @… | new / awaiting-you / already-replied | … |

- **Status**:
  - `new` — no reply from the PR author yet (`author_replied_last == false` and no prior author comment).
  - `awaiting-you` — reviewer followed up after the PR author's reply (`reviewer_followed_up == true`). High priority.
  - `already-replied` — PR author had the last word, no follow-up. Filtered out by default; only appears if the user asks to see them.
  - For PR-level review bodies (`reviews`) and `issue` comments, fall back to `new`/`previous` based on timestamps — no thread structure to inspect.
- **Source**: `inline` (GraphQL thread), text from **`reviews`**, or `issue` for 2c.
- Group obvious duplicate nits (same reviewer, same theme across files) into one **cluster** with one row or a merged summary.
- Below the table, add a one-line note: `Skipped N already-replied thread(s) — say "show already-replied" to include them.` Omit the line if `N == 0`.

---

## Step 5 — Ask the user per thread

Use `AskUserQuestion` with the **recommended action first**:

```
Title: Thread 2/6 · CRITICAL · src/auth.py L45
Prompt: @alice flags SQL injection in raw query construction. Suggest: fix (easy). What should I prepare?
Options:
  1. Both — fix plan + acknowledging reply   [recommended]
  2. Plan the fix only
  3. Draft a reply only
  4. Multiple solutions — show 2–3 options, I will pick
  5. Skip / other (I will type what I want)
```

Rules:

- Recommended option is always **first** (keyboard default).
- Near-duplicate threads → one question, one shared reply, per-file links.
- One `AskUserQuestion` per thread or cluster, then emit that block before continuing. Never loop silently.

---

## Step 6 — Output format per thread

Use escaped inner fences so the outer example stays valid markdown. Emit this shape in chat after the user picks an action:

```
### Thread <n> · <SEVERITY> · [<path> (L<line>)](https://github.com/<OWNER>/<REPO>/blob/<SHA>/<path>#L<line>)
Reviewer: @<login> — <one-line summary>
Thread: <github thread url>
Recommendation: <fix | reply | both | skip>  ·  Feasibility: <easy | needs-discussion | out-of-scope>

Fix plan (when fix or both):
- What: <one or two sentences>
- Where: [<path> (L<line>)](https://github.com/<OWNER>/<REPO>/blob/<SHA>/<path>#L<line>)[, other files]
- Feasible: yes | needs-discussion | no — <why>
- Alt 1: <if any>
- Alt 2: <if any>

Suggested reply (paste on GitHub):
\`\`\`text
<reply — no semicolons in prose>
\`\`\`

Optional — Suggested change (on the correct line in the PR UI):
\`\`\`suggestion
<replacement lines>
\`\`\`
```

Drop sections that do not apply. **`reply`-only** → no fix plan, no suggestion. **`skip`** → one line explaining why.

For **`isOutdated: true`**, keep the thread if still unresolved, mark **`outdated`** next to the line, lean on the thread URL.

---

## Step 7 — Wrap-up

- Counts by **recommendation** and by **severity**
- Count of **already-replied** threads skipped (if any), with the one-line opt-in reminder
- Manual next steps in order: apply fixes → paste replies → push → resolve threads on GitHub
- Reminder: this skill did not post or edit anything **unless** the user opted in to Step 8
- One-line nudge if not opted in: `Tip: say "wrzuć jako draft" / "submit as pending review" to upload these replies as a PENDING GitHub review you can submit from the UI.`

---

## Step 8 — Submit as pending draft review (opt-in only)

Runs only when the user explicitly opts in (see triggers in **Constraints**). The skill creates a **PENDING** GitHub review containing every prepared `reply` / `both` reply as an inline comment, scoped to the `(path, line)` of the source thread. Nothing is submitted — the user reviews and submits from the GitHub UI.

### Preconditions

- Step 1 captured `OWNER`, `REPO`, `NUMBER`, `headRefOid` (= `SHA`).
- Every reply targets a real `(path, line)` from the source thread (use `line` from GraphQL — fall back to `originalLine` only when `line` is null).
- `skip`-only and PR-level review bodies cannot be attached as inline comments — list them at the end of the body of the review instead, or omit.

### Build the payload

Collect the prepared replies into a JSON array. Each entry MUST have `path`, `line`, `body`, and `side` (default `"RIGHT"`). For multi-line ranges, also include `start_line` and `start_side: "RIGHT"`.

```bash
COMMENTS_JSON=$(jq -n '[
  {path: "src/auth.ts", line: 17, side: "RIGHT", body: "Reply text\n\n```suggestion\nif (!user) throw new UnauthorizedException();\n```"},
  {path: "src/user.controller.ts", line: 88, side: "RIGHT", body: "Fair point — see thread for the trade-off."}
]')
```

### Create the pending review

```bash
jq -n \
  --arg sha "$SHA" \
  --arg body "Draft review prepared by g-pr-triage. Submit or discard from the PR UI." \
  --argjson comments "$COMMENTS_JSON" \
  '{commit_id: $sha, body: $body, comments: $comments}' \
| gh api "repos/$OWNER/$REPO/pulls/$NUMBER/reviews" \
    -X POST --input - --jq '.id'
```

`event` is **omitted on purpose** — that's what makes the review PENDING. The response `id` is the review id; show it to the user.

### After submit (chat output)

```
✅ Pending review created on PR #<NUMBER>.
Open in browser: <PR_URL>/files
Review id: <id>
Inline comments: <count>  ·  Skipped (no anchor): <count>

Submit or discard from the PR UI — this skill did not auto-submit.
```

### Failure cases (do not retry silently)

| Failure | Action |
|---------|--------|
| 422 `pull_request_review_thread.line must be part of the diff` | The `(path, line)` no longer matches the PR diff at `SHA` (outdated thread). Drop that comment from the payload, report which one was skipped, retry. |
| 401 / 403 | Auth issue — tell the user to run `gh auth status`, stop. |
| Non-2xx other | Print the API error verbatim, stop. Do **not** auto-retry. |

### Things to avoid

- Never pass `event: "COMMENT" | "APPROVE" | "REQUEST_CHANGES"` — that auto-submits.
- Never call `gh pr review --approve` / `--request-changes` / `--comment`.
- Never delete or edit existing comments / reviews on the PR.

---

## Examples

### Reply only (style)

**Thread line:** `### Thread 1 · LOW · [apps/api/src/user.controller.ts (L88)](https://github.com/acme/api/blob/abc123/apps/api/src/user.controller.ts#L88)`  
**Reviewer:** `@alice` — prefers `readonly` on injected services  
**Thread URL:** `https://github.com/acme/api/pull/42#discussion_r123`  
**Recommendation:** `reply` · **Feasibility:** `easy`

Suggested reply (paste on GitHub):

```text
Fair point. We keep constructor params without `readonly` in this module for consistency with other controllers. Happy to do a follow-up PR that applies `readonly` everywhere at once.
```

### Fix with suggestion

**Thread line:** `### Thread 2 · HIGH · [apps/api/src/auth/guard.ts (L17)](https://github.com/acme/api/blob/abc123/apps/api/src/auth/guard.ts#L17)`  
**Reviewer:** `@bob` — missing null check on `user`  
**Recommendation:** `fix` · **Feasibility:** `easy`

Fix plan bullets: return 401 when `user` is nullish before reading `user.id` at [apps/api/src/auth/guard.ts (L17)](https://github.com/acme/api/blob/abc123/apps/api/src/auth/guard.ts#L17). Feasible — single guard.

Optional suggested change:

```suggestion
    if (!user) throw new UnauthorizedException();
    return user.id === ctx.params.id;
```

---

## Troubleshooting

| Problem | What to do |
|---------|------------|
| `gh` not authenticated | `gh auth login` |
| No PR for current branch | Ask for PR number or URL |
| Fork / ambiguous repo | Pass `-R owner/repo` from the PR URL |
| More than 100 threads | `fetch-comments.sh` paginates until done — if you inlined the query instead, use `after` cursors |
| Reviewer already suggested code | Acknowledge their suggestion, do not duplicate the same diff |
| Script errors | Ensure `bash`, `jq`, and `gh` are installed. On Linux, scripts use POSIX-friendly parsing (no `grep -P`) |

---

## Internal checklist

- [ ] PR resolved (`OWNER`, `REPO`, `NUMBER`, `headRefOid`, PR URL)
- [ ] `fetch-comments.sh` run — unresolved threads (with `author_replied_last` / `reviewer_followed_up` enrichment)
- [ ] `fetch-reviews.sh` run — `reviews` + `inline_comments`
- [ ] Already-replied threads filtered out by default; count surfaced
- [ ] Severity + recommendation + feasibility per remaining (live) thread or cluster
- [ ] Summary table shown before `AskUserQuestion` rounds, with `Status` and skipped-count note
- [ ] `AskUserQuestion` per thread or cluster, recommended option first
- [ ] Per-thread block: severity, GitHub blob link + thread URL, fenced reply, optional `suggestion`
- [ ] No semicolons in prose inside replies
- [ ] No GitHub writes by default — Step 8 only on explicit opt-in
- [ ] Wrap-up with counts, manual next steps, and pending-draft opt-in nudge
