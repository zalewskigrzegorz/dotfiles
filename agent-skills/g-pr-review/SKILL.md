---
name: g-pr-review
description: Interactive PR code review for Claude Code. Analyzes a pull request (current branch, PR number, or GitHub URL) for security, performance, quality, and tests, then asks per finding whether to post each comment (with a recommendation), and finally whether to APPROVE / REQUEST_CHANGES / COMMENT — submitting one real review via gh. Use whenever the user wants to review a PR, leave PR comments, or approve/request changes, even if they don't say "review" explicitly.
---

# g-pr-review

Review a PR, then decide interactively — per finding — what to post, and submit one real GitHub review at the end. The goal is to spend as few tokens and round-trips on the *conversation* as possible: do the analysis silently, then ask compact questions. Never dump the diff, code blocks, or a long markdown report into the chat — the questions carry everything the user needs to decide.

## Language

The review content (comment bodies, summary) is **English**, even if the conversation is in another language. The interactive questions can match the user's language.

## Flow

1. **Resolve the target** and capture identifiers.
2. **Analyze the diff silently** into a list of findings. Do not print the report.
3. **Ask per finding** (Post / Skip) in batched questions, with a recommendation each.
4. **Ask the verdict** (Approve / Request changes / Comment / Don't submit), with a recommendation.
5. **Submit one review** via `gh api`, then report the review URL.

## 1. Resolve the target

- **Current branch:** `gh pr view --json number,url,title,baseRefName,headRefName,headRefOid,headRepositoryOwner,headRepository`. If no PR exists for HEAD, fall back to `git diff <default-branch>...HEAD`.
- **PR number:** `gh pr view <n> --json …` (add `-R owner/repo` if ambiguous).
- **PR URL:** parse `owner`/`repo`/`number` from the URL.

Capture `OWNER` (`headRepositoryOwner.login`), `REPO` (`headRepository.name`), `NUMBER`, and `SHA` (`headRefOid`). Get the diff with `gh pr diff <n>`.

## 2. Analyze silently

Review across these categories, but only surface things that genuinely matter — false positives waste the user's time:

- **Security:** injection (SQL/command/XSS), insecure deserialization, hardcoded secrets, weak authz/authn, IDOR.
- **Performance:** N+1 queries, missing indexes, needless re-renders, memory leaks, blocking async, missing caching.
- **Quality:** DRY/SRP violations, deep nesting, magic values, naming, error handling, typing gaps.
- **Testing:** missing coverage for new behavior, non-asserting tests, flaky patterns, over-mocking.

For each finding, record: `severity` (Critical / Suggestion / Nit), `path`, `line`, a one-line `title`, a one-line `why`, the exact `comment_body` (the English text that would be posted), and a `recommended_action` (Post or Skip).

**Anchoring:** `line` must be a line that appears in the diff (right side for added/changed code, `side: "LEFT"` for removed lines). If a finding can't be anchored to a diff line, fold it into the review summary body instead of posting it inline.

## 3. Ask per finding

Use `AskUserQuestion`. Batch up to 4 findings into one call (one question per finding) so the whole selection is a few round-trips, not one per item. For each finding:

- **header:** the severity (`Critical`, `Suggestion`, `Nit`).
- **question:** `<path>:<line> — <title>`.
- **options:** `Post` and `Skip`. Put the recommended one first and append ` (Recommended)` to its label. Each option's `description` carries the **why** and the exact comment body that will be posted — so the user decides from the question alone, with no code shown in chat.

Recommend `Post` for Critical findings by default; use judgment for Suggestions/Nits. If there are zero findings, skip straight to step 4.

## 4. Ask the verdict

One `AskUserQuestion`, single question: `"<N> comments selected — submit review as?"`. Options:

- **Approve** — no blocking issues.
- **Request changes** — there are unaddressed Critical findings.
- **Comment only** — feedback without a verdict (also the only valid event on your own PR).
- **Don't submit** — abort, post nothing.

Recommend **Request changes** if any Critical finding was selected; otherwise **Approve** (or **Comment only** when there are non-trivial suggestions). Mark the recommended option `(Recommended)`.

## 5. Submit

Map the verdict → event: Approve→`APPROVE`, Request changes→`REQUEST_CHANGES`, Comment only→`COMMENT`, Don't submit→abort (report that nothing was posted).

Build the payload and submit one review in a **single `Bash` call**, piping JSON to `gh api` via stdin heredoc. Do NOT write the payload to a file first — a fixed path like `/tmp/g-pr-review.json` collides with stale files from earlier runs, and the `Write` tool then refuses to overwrite ("must read first"). Stdin avoids the temp file entirely:

```bash
gh api --method POST "repos/<OWNER>/<REPO>/pulls/<NUMBER>/reviews" --input - <<'JSON'
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

If you genuinely need a file (e.g., the payload is huge or you want to inspect it), use `mktemp` so the path is unique per invocation: `PAYLOAD=$(mktemp -t g-pr-review.XXXXXX.json)` — never a fixed `/tmp/g-pr-review.json`.

- Multi-line anchors: add `"start_line": <n>` alongside `"line"`.
- Empty `comments` is fine (clean approve / verdict-only).
- **Own PR:** `APPROVE`/`REQUEST_CHANGES` return HTTP 422 on your own PR. If that happens, resubmit with `event: "COMMENT"` and tell the user.

Report the resulting review URL (from the API response `html_url`). Keep the closing message to one line — don't re-print the comments.


## Comment writing rules

Write like a senior engineer leaving a quick review note, not like an AI assistant.

- **Lead with the point.** State the issue or ask directly. No "Great work!", "Good catch", "I noticed that…", "It seems like…", "Consider…" preambles.
- **Concrete, not abstract.** Name the exact symbol/line/behavior. "`user` can be null here → 401" beats "There might be a potential issue with null handling."
- **Show, don't describe.** If a fix fits in a line or two, give a `suggestion` block or inline code instead of prose explaining it.
- **One issue per comment.** Don't bundle unrelated points or pad with extra advice the reviewer didn't ask about.
- **Say why only when it's not obvious.** Skip rationale for trivial stuff. For real bugs, one short clause is enough ("…otherwise it throws on empty input").
- **No hedging, no filler.** Cut "I think", "maybe", "just", "simply", "in order to", "it's worth noting". No closing pleasantries ("Hope this helps!", "Let me know!").
- **Match length to weight.** Nit = one line. Real bug = 1–3 lines max. Never a paragraph for a small thing.
- Plain technical English. No emoji unless mirroring the reviewer's own.
