---
name: g-pr-review
description: Reviews a PR from the current branch, PR number, or GitHub URL using gh/git diffs, outputs an English summary with Critical/Suggestions/Nits and suggested review comments for manual posting. Use when the user wants a PR code review without auto-submitting review comments.
---

# g-pr-review

## When to use

User wants a review of a pull request: quality, security, performance, tests—either on the **current branch**, a **PR number**, or a **PR URL**. Output is for the user to verify and paste comments manually unless they explicitly ask to submit via `gh`.

## Language

The entire review (summary, findings, suggested comments) must be **English**, even if the conversation is in another language.

## Output style rules

Follow these in **every** review you produce.

1. **No semicolons in prose**  
   Do not use `;` in any review text (headings, bullets, Why, Suggested fix, intro lines, or suggested comments). Split ideas with new sentences, commas, or em dashes. Code snippets and URLs may contain `;` when they are literal code.

2. **Clickable links to the exact file**  
   For each finding, include at least one **markdown link** to the repo path so the reader can open the file in the IDE in one click. Use workspace-relative paths from the repo root, for example `[apps/api/src/foo.ts](apps/api/src/foo.ts)`. Add the approximate line after the link in plain text if helpful, for example `(around line 42)` or `` `L42` `` in backticks—avoid `file:line` syntax that is not a link unless you also provide the link.

3. **Paste-ready review comments in code fences**  
   Every **Suggested review comment (paste on GitHub)** must be the **only** content inside a markdown **fenced code block** (use ` ```text ` … ` ``` ` or bare ` ``` `). That way copy-paste keeps spacing and line breaks. The text inside the fence is plain English for GitHub, not markdown.

4. **Tone**  
   Sound **friendly, casual, and professional**. Be clear about what you would change or ask for. Stay polite. A little light humor is fine when it fits. Do not sound stiff, robotic, or embarrassing.

## Resolve what to review

1. **Current branch:** run `gh pr view --json number,url,title,baseRefName,headRefName` (from repo root). If no PR exists for HEAD, fall back to `git diff <default-branch>...HEAD` after detecting default branch (`main` / `master` via `gh repo view --json defaultBranchRef` or `git symbolic-ref refs/remotes/origin/HEAD`).
2. **PR number:** `gh pr view <n> --json ...` and `gh pr diff <n>` in the current repo. If repo is ambiguous, use `-R owner/repo` from context.
3. **PR URL:** parse `owner`, `repo`, and `number`, then `gh pr diff <n> -R owner/repo` and `gh pr view`.

Gather the full diff (`gh pr diff`) and optionally the list of changed files from `gh pr view --json files`.

## Where to leave a comment (IDE-friendly links)

- Prefer linking the **file that should change** or the **clearest anchor** (controller, middleware, schema, test, OpenAPI path). If two files should move together, link both.
- Example for a nit about handler status code: primary link [`apps/api/src/modules/api/example/example.controller.ts`](apps/api/src/modules/api/example/example.controller.ts), optional second link [`docs/openapi/paths/example.yaml`](docs/openapi/paths/example.yaml).
- The reader uses the link to jump in Cursor or VS Code, then adds the review comment on the right line. You still describe the issue in words so they know where to click inside the file if the line shifts.

## Review categories

### 1. Security

SQL injection, XSS, command injection, insecure deserialization, hardcoded secrets, weak authz/authn, IDOR.

### 2. Performance

N+1 queries, missing indexes, unnecessary re-renders, memory leaks, blocking async, missing caching, bundle size concerns.

### 3. Code quality

DRY violations, SRP violations, deep nesting, magic values, naming, error handling, typing gaps.

### 4. Testing

Missing coverage for new behavior, tests that do not assert behavior, flaky patterns, missing edge cases, over-mocking.

## Output format (markdown)

Use this structure. **No automatic `gh pr review`** unless the user explicitly requests it.

**Required shape**

- Top heading: `## Code review summary`
- Sections: `### Critical (must fix)`, `### Suggestions (should consider)`, `### Nits (optional)`, `### What is working well`
- Each finding is one top-level bullet. The first line must include a **markdown link** to the file, e.g. `[apps/api/src/foo.ts](apps/api/src/foo.ts)`, plus a short title (optional line hint in words or `` `L12` ``)
- Nested bullets: **Why** and **Suggested fix** when they add value
- **Suggested review comment (paste on GitHub):** must be followed by a **fenced code block** (open with three backticks, optional `text` label, newline, the comment, newline, three backticks). Put only the GitHub comment inside the fence so copy-paste stays clean

**Example fragment (match this pattern in real reviews)**

### Suggestions (should consider)

- **[apps/api/src/example.ts](apps/api/src/example.ts)** (`L40`) — validate input before use
  - **Why:** Missing checks can let bad data hit the DB
  - **Suggested fix:** Add a zod schema or DTO validation at the boundary
  - **Suggested review comment (paste on GitHub):**

```text
Could we validate this body with the same zod DTO as the public route? Would make bad payloads fail fast with a clear 400.
```

Keep suggested review comments short, polite, and actionable (one thread per distinct topic). Inside the paste-ready fence, avoid semicolons in prose unless you are pasting a literal code snippet.

## Reference patterns (examples only)

**Security — bad SQL interpolation:** Flag raw string concatenation and suggest parameterized queries.

**Performance — N+1:** Flag per-item awaits in a loop and suggest batching or a single query.

**Error handling:** Flag empty `catch` blocks and suggest logging plus rethrow or typed errors.

## Checklist (internal)

- [ ] No hardcoded secrets
- [ ] Input validation where needed
- [ ] Errors handled or propagated
- [ ] Types/interfaces adequate
- [ ] New logic has tests where appropriate
- [ ] No obvious performance regressions
- [ ] Breaking changes called out if any
- [ ] Output follows **Output style rules** (no semicolons in prose, file links, fenced paste-ready comments, tone)
