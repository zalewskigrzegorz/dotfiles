# g-pr shared primitives

Reference file for `g-pr-review` and `g-pr-respond`. **Not a skill** — this
directory deliberately has no `SKILL.md`, so nothing registers it, nothing
auto-triggers it, and it costs no description context. Read it when either skill
points here; never invoke it directly.

P2 (the ownership guard) is deliberately absent: `g-pr-review` needs a three-way
mine / not-mine / no-PR exit to pick its flow, `g-pr-respond` needs a two-way
guard. Each keeps its own copy.

These apply to both flows below.

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

After first call in a session, subsequent runs read from env — saves one API hit per re-invocation.

---

## P1. Resolve the target

Capture `OWNER`, `REPO`, `NUMBER`, `SHA` (`headRefOid`), and the PR URL. Pass `-R "$OWNER/$REPO"` on every `gh` call when working from a PR URL or across forks.

**When `USE_LOCAL=true` from P0**, derive locally and only call `gh pr view` for the PR-side fields (number, URL, author):

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

## P3. `AskUserQuestion` conventions

* **Batch up to 4 questions per call.** One question per finding/thread, all four in the same `AskUserQuestion`. Never loop one-by-one when 2+ items are pending — that's the doubled-up feel to avoid.
* **Recommended option first**, with ` (Recommended)` appended to its label. Claude Code defaults to option 1.
* Each option's `description` carries the **why** and (where applicable) the exact comment/reply body, so the user decides from the question alone — no code dumped in chat.
* Severity order: CRITICAL → HIGH → MEDIUM → LOW (or Critical → Suggestion → Nit for fresh reviews).

## P4. Cluster duplicates

Near-duplicate findings/threads (same reviewer, same theme, same nit class — e.g. CodeRabbit firing five identical "missing `readonly`" hits) → cluster into **one** question with one shared comment/reply, list the per-file links inside.

## P5. Comment writing rules

Write like a senior engineer leaving a quick review note, not like an AI assistant.

* **Lead with the point.** State the issue or ask directly. No "Great work!", "Good catch", "I noticed that…", "It seems like…", "Consider…" preambles.
* **Concrete, not abstract.** Name the exact symbol/line/behavior. "`user` can be null here → 401" beats "There might be a potential issue with null handling."
* **Show, don't describe.** If a fix fits in a line or two, give a `suggestion` block or inline code instead of prose explaining it.
* **One issue per comment.** Don't bundle unrelated points or pad with extra advice the reviewer didn't ask about.
* **Say why only when it's not obvious.** Skip rationale for trivial stuff. For real bugs, one short clause is enough ("…otherwise it throws on empty input").
* **No hedging, no filler.** Cut "I think", "maybe", "just", "simply", "in order to", "it's worth noting". No closing pleasantries ("Hope this helps!", "Let me know!").
* **Match length to weight.** Nit = one line. Real bug = 1–3 lines max. Never a paragraph for a small thing.
* **No semicolons in prose.** New sentences, commas, or em dashes. Literal code may use `;`.
* Plain technical English. No emoji unless mirroring the reviewer's own.

## P5.5. Voice gate (mandatory)

P5 is how you write the first draft. The `greg-voice` skill is the net that catches what still slips through — review comments here keep reading as machine-generated even after P5. So **every body bound for GitHub passes through the `greg-voice` skill before the user sees it for confirmation**: inline comments, thread replies, review summary bodies, verdict rationales. If it gets posted, it went through the voice first — no exceptions.

How to run it without burning the whole turn:

* **Load the `greg-voice` skill once per run** (Skill tool), the first time you draft any GitHub-bound text. It stays loaded for the rest of the flow — don't re-invoke per comment.
* **Humanize per batch, not per comment.** Once you've drafted the ≤4 bodies for an `AskUserQuestion` batch, run all of them through greg-voice together, then put the *voiced* versions into the question. The user should only ever see post-voice text.
* **Full voice, including here.** A review comment is not an exception — it should read like Greg typed it in the PR: point first, casual, plainly owned. Keep every exact path, line number, version and limit; drop the stiff register around them. "It appears that this implementation may not correctly handle…" becomes "this breaks when the list is empty — line 42". Never flatten it into a neutral senior-engineer note.
* **Don't re-humanize `Modify` text.** When Greg pastes a reply himself, it's already human — post it verbatim.

Why batch: a per-comment full-skill pass on a 20-thread PR is slow, and it tempts the model to inflate a terse nit into a chatty paragraph. Casual is not longer — a terse nit stays terse. A one-line nit that's already clean should come back as the same one line.

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
