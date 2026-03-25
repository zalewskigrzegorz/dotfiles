---
name: g-pr-review
description: Reviews a PR from the current branch, PR number, or GitHub URL using gh/git diffs, outputs an English summary with Critical/Suggestions/Nits and suggested review comments for manual posting. Use when the user wants a PR code review without auto-submitting review comments.
---

# g-pr-review

## When to use

User wants a review of a pull request: quality, security, performance, tests—either on the **current branch**, a **PR number**, or a **PR URL**. Output is for the user to verify and paste comments manually unless they explicitly ask to submit via `gh`.

## Language

The entire review (summary, findings, suggested comments) must be **English**, even if the conversation is in another language.

## Resolve what to review

1. **Current branch:** run `gh pr view --json number,url,title,baseRefName,headRefName` (from repo root). If no PR exists for HEAD, fall back to `git diff <default-branch>...HEAD` after detecting default branch (`main` / `master` via `gh repo view --json defaultBranchRef` or `git symbolic-ref refs/remotes/origin/HEAD`).
2. **PR number:** `gh pr view <n> --json ...` and `gh pr diff <n>` in the current repo; if repo is ambiguous, use `-R owner/repo` from context.
3. **PR URL:** parse `owner`, `repo`, and `number`, then `gh pr diff <n> -R owner/repo` and `gh pr view`.

Gather the full diff (`gh pr diff`) and optionally the list of changed files from `gh pr view --json files`.

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

```markdown
## Code review summary

### Critical (must fix)
- **File:line** — [issue]
  - **Why:** …
  - **Suggested fix:** …
  - **Suggested review comment (paste on GitHub):** …

### Suggestions (should consider)
- **File:line** — …
  - **Why:** …
  - **Suggested fix:** …
  - **Suggested review comment (paste on GitHub):** …

### Nits (optional)
- **File:line** — …
  - **Suggested review comment (paste on GitHub):** …

### What is working well
- …
```

Keep suggested review comments short, polite, and actionable (one thread per distinct topic).

## Reference patterns (examples only)

**Security — bad SQL interpolation:** flag raw string concatenation; suggest parameterized queries.

**Performance — N+1:** flag per-item awaits in a loop; suggest batching or a single query.

**Error handling:** flag empty `catch`; suggest logging and rethrow or typed errors.

## Checklist (internal)

- [ ] No hardcoded secrets
- [ ] Input validation where needed
- [ ] Errors handled or propagated
- [ ] Types/interfaces adequate
- [ ] New logic has tests where appropriate
- [ ] No obvious performance regressions
- [ ] Breaking changes called out if any
