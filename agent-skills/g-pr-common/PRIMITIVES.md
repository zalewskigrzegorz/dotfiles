# g-pr shared primitives

Reference for `g-pr-review` and `g-pr-respond` (P5 also for `g-pr`, P10 also
for `g-pr-fix-checks` and `babysit-prs`). **Not a skill**: no `SKILL.md`, so it
never triggers and costs no description context. Read it once per run, with
`Read`, when a skill points here.

P2 (ownership guard) lives in each skill: both compare `$ME` (P0b) with
`author.login` (P1), then branch differently.

**Language.** Anything posted to GitHub (review bodies, inline comments, thread
replies, verdicts) is English. Chat with Greg stays in his language.

## P0. Local-first resolution (run first)

Threads always come from `gh`; diff and identity can come from the local
checkout when it matches the remote.

### P0a. Detect working state

```bash
BRANCH="$(git branch --show-current 2>/dev/null || echo)"
DIRTY="$(git status --porcelain 2>/dev/null | head -1)"
if [[ -n "$BRANCH" ]]; then
  # no `|| true` on fetch: it once hid `Permission denied (publickey)` and USE_LOCAL stayed true on a moved head
  if git fetch origin "$BRANCH" --quiet; then
    LOCAL_SHA="$(git rev-parse HEAD 2>/dev/null || echo)"
    REMOTE_SHA="$(gh pr view --json headRefOid --jq .headRefOid 2>/dev/null || git rev-parse "origin/$BRANCH" 2>/dev/null || echo)"
    [[ -n "$REMOTE_SHA" && "$LOCAL_SHA" == "$REMOTE_SHA" ]] && USE_LOCAL=true || USE_LOCAL=false
  else
    USE_LOCAL=false; echo "fetch padł (ssh), liczę po API"
  fi
else
  USE_LOCAL=false   # PR by number/URL, not checked out
fi
```

| State | Action |
|---|---|
| `USE_LOCAL=true`, clean | Local git for diff/identity, skip `gh pr diff`. |
| `USE_LOCAL=true`, `DIRTY` | Warn "uncommitted changes, using the committed state", then local. |
| `false`, `git merge-base --is-ancestor HEAD "origin/$BRANCH"`, clean | `git merge --ff-only "origin/$BRANCH"`, `USE_LOCAL=true`, one line "fast-forward `<old>` → `<new>`". |
| `false`, diverged or local ahead | Warn "local `<short>` differs from `origin/<branch>` `<short>`, using the API", `gh pr diff`. |
| `false`, no branch | Silent API fallback. |

State `USE_LOCAL=<…>` in one line next to the P2 line. Greg can override
("force fresh API", "trust local").

### P0b. Identity cache

```bash
ME="${G_PR_ME:-$(gh api user --jq .login)}"; export G_PR_ME="$ME"
```

## P1. Resolve the target

Capture `OWNER`, `REPO`, `NUMBER`, `SHA` (`headRefOid`), `AUTHOR`
(`author.login`, from the same response), URL. From a PR URL or a fork, `-R
"$OWNER/$REPO"` on every `gh` call.

```bash
# USE_LOCAL=true: OWNER/REPO from `git config --get remote.origin.url`, SHA from `git rev-parse HEAD`, plus
gh pr view --json number,url,author,baseRefName
# otherwise:
gh pr view [<n>] --json number,url,title,baseRefName,headRefName,headRepositoryOwner,headRepository,headRefOid,author
export G_PR_NUMBER="$NUMBER" G_PR_OWNER="$OWNER" G_PR_REPO="$REPO"
```

No PR for HEAD and no number/URL given → stop and ask.

**Load `work-people` here, before the first line to Greg**, and resolve
`AUTHOR` and every login the run will name (reviewers, thread authors,
competing PR authors) in one `rg -i 'a|b|c'`. Chat, popups and the closing
mail use full names. `Autor: @login` in a brief is not resolved (da31126c).

## P3. `AskUserQuestion` conventions

- **One finding or reply per popup, chained**, the draft in the options'
  `preview`. Two drafts in one call were both rejected. Only exception: the
  `g-pr-respond` A4 fast path when Greg asks ("hurtem", "szybko").
- Recommended option first, `(Recommended)` on its label.
- Each `description` carries the why (and the body where it applies); no code
  dumped in chat.
- Severity order CRITICAL → HIGH → MEDIUM → LOW (fresh review: Critical →
  Suggestion → Nit).
- PR number never in `question` (guard denies digits): it goes in
  `description`. Every PR or branch named carries its title or a one-line
  what-it-does.

## P4. Cluster duplicates

Near-duplicates (same reviewer, same theme, e.g. five identical "missing
`readonly`" bot hits) → one question, one shared comment, per-file links inside.

## P5. Comment writing rules

Write like a senior engineer's quick note.

- **Point first.** No "Great work!", "Good catch", "I noticed that…", "It
  seems like…", "Consider…".
- **Concrete**: exact symbol/line/behaviour ("`user` can be null here → 401").
- **Show, don't describe**: a fix of 1–2 lines is a `suggestion` block or
  inline code.
- **Issue/PR references are full URLs**, never a bare `#n` (tuicr and GitHub).
- **One issue per comment**, no extra advice.
- **Why only when not obvious**, one short clause for real bugs.
- **No hedging or filler** ("I think", "maybe", "just", "simply", "in order
  to", "it's worth noting", "Hope this helps!").
- **Length matches weight**: nit = one line, real bug 1–3 lines.
- **No semicolons in prose** (code may have them). Plain English, no emoji
  unless mirroring the other side.
- **"False alarm" only after a test**: reproduce with a control run that shows
  the check can fail; first line says how ("False alarm, tested 4.0 and 4.2
  against a fake floci"). Only read the code → "read the code, didn't run it".
- **"Missing / do it separately" only after searching issues**: `gh search
  issues --repo <owner/repo> "<term>" --json number,title,state` (epics too),
  numbers in the draft.

## P5.5. Voice gate (mandatory)

Every GitHub-bound body (inline comments, replies, review bodies, verdict
rationales, tuicr drafts) passes `greg-voice` before Greg sees it.

- Load `greg-voice` once per run; voice all drafts of the run in one batch,
  then show only the voiced text.
- Full voice, review comments included: point first, casual, every path, line,
  version and limit kept. A terse nit stays terse.
- Text Greg typed himself (`Modify`) is posted verbatim, no voice pass.

## P6. Blob links

`[<path> (L<line>)](https://github.com/<OWNER>/<REPO>/blob/<SHA>/<path>#L<line>)`,
`-L<end>` for a range; a thread-anchored comment also shows the thread URL.

## P7. Scripts location

```bash
SCRIPTS="${G_PR_REVIEW_SCRIPTS:-$(git rev-parse --show-toplevel)/.claude/skills/g-pr-review/scripts}"
[[ -d "$SCRIPTS" ]] || SCRIPTS="$HOME/.claude/skills/g-pr-review/scripts"
[[ -d "$SCRIPTS" ]] || SCRIPTS="$HOME/.cursor/skills/g-pr-review/scripts"
[[ -d "$SCRIPTS" ]] || echo "g-pr-review scripts not found → place-work-skills $(git rev-parse --show-toplevel)"
```

`g-pr-review` is work-scoped (`bin/sync` places it in the repo's
`.claude/skills/`), so the repo path comes first.

- `fetch-comments.sh OWNER REPO NUMBER`: unresolved threads (GraphQL,
  paginated) with `pr_author`, `last_comment_author`, `last_comment_at`,
  `author_replied_last`, `reviewer_followed_up`; `comments[0]` opens,
  `comments[-1]` is latest.
- `fetch-reviews.sh OWNER REPO NUMBER`: review bodies + top-level inline
  comments (humans and bots).

## P8. Rate limits

`403` with `secondary rate limit`: wait ~30 s, retry once; second failure →
surface it and ask.

## P9. Posting a thread reply

1. Popup per reply, chained (P3): question "Post this reply?", the voiced body
   in `preview`, options **Yes — post it** (Recommended) · **Modify** · **No —
   skip**. The Yes is the confirmation, no extra prompt.
2. `gh api "repos/$OWNER/$REPO/pulls/$NUMBER/comments/$COMMENT_ID/replies" -X
   POST -f body="$REPLY_BODY"`. `$COMMENT_ID` = `databaseId` of the thread's
   **first** comment (`.comments[0]`): a reply's id gives 404 or a 500 that
   looks like an outage.
3. 5xx → one try via GraphQL with the thread node id:
   ```bash
   gh api graphql -f query='mutation($t:ID!,$b:String!){addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$t,body:$b}){comment{url}}}' -f t="$THREAD_ID" -f b="$REPLY_BODY"
   ```
   Fails too → print the voiced reply as plain paragraphs with the thread URL,
   end the turn ("wklej ręcznie albo powiedz wyślij").
4. Success → `✅ Posted: <html_url>`. 422/404/403 → print verbatim, ask
   (retry / modify / skip); no auto-retry except P8. `Modify` → "Paste the new
   reply text", post the next message verbatim.
5. `422 … line must be part of the diff`: thread outdated; usually irrelevant
   for `/replies`, else modify or skip. `originalLine` off by >~5 from the
   current line → warn, post anyway, link uses the current SHA.

## P10. Unattended tuios tab: close with a mail

When the first message has a `Raport:` line (a `workctl` tab, `bin/pr-brief`)
and `TUIOS_PANE_ID` is set. Questions stay `AskUserQuestion`. Last step, after
the URL or summary line:

```bash
tuios send-agent-message -w human --from "$TUIOS_PANE_ID" --subject 'PR #<n>: <verdict>' '<≤5 lines: done, posted, what waits on Greg>'
```

Subject ≤120 chars (`PR #31204: 3 replies posted, 1 skipped`), body in
Polish, no recap of comments. The mail dies with the session (`workctl rm
--self`), so a run that closes its worktree carries the verdict in its closing
question instead, or on APPROVE leaves the review on GitHub as the report.

## P11. Shared never

- No post without an explicit Yes; no GitHub-bound body that skipped P5.5.
- Nothing non-English on GitHub.
- Never delete or edit other people's comments on the PR.
- Never `--no-verify`; a failed pre-commit hook → fix, re-stage, a **new**
  commit (no `--amend`).

## P12. Troubleshooting

| Problem | Do |
|---|---|
| `gh` not authenticated | `gh auth login` |
| No PR for the branch | ask for number or URL |
| Fork / ambiguous repo | `-R owner/repo` from the URL |
| >100 threads | `fetch-comments.sh` paginates |
| Reviewer already suggested code | acknowledge it, don't duplicate the diff |
| Script errors | `bash`, `jq`, `gh` installed? |

## Per-run checklist (both skills)

P0 `USE_LOCAL` stated, dirty/mismatch warned · `$G_PR_ME` cached · P1
resolved, logins → full names · P2 stated · P3 one per popup · P5 rules,
English · P5.5 voiced in one batch · P6 links pinned to `SHA`.
