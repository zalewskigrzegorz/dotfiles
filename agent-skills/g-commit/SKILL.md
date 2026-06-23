---
name: g-commit
description: Generates conventional commit messages from `git diff --cached` per commitlint and appends one gitmoji at the end of the subject. In configured work repos it also creates a feature branch off main/master and runs `git commit`; in other repos it only **suggests** the message and the user commits themselves. Pushing is always the user's responsibility. Use when the user asks to commit staged changes, write a commit message, or align with conventional commits / commitlint.
---

# g-commit

## When to use

The user asks to commit staged changes, write a commit message, or align with commitlint / conventional commits.

## Language

All **generated** text (commit message subject/body) must be **English**, even if the conversation is in another language.

## Push policy (applies to every mode, no exceptions)

This skill never runs `git push`, never opens a PR, never sets upstream. Pushing the branch and opening a PR is the user's job — always. If they want a PR after committing, point them at the `g-pr` skill.

## Modes

The skill operates in one of two modes:

- **work mode** — full flow: branch guard on `main`/`master`, then run `git commit`.
- **suggest-only mode** — print the proposed commit message and stop. No `git add`, no `git commit`, no branch creation.

The point of suggest-only mode is that personal / OSS / scratch repos shouldn't get a Claude-driven commit pipeline imposed on them — the user wants to decide when and how to commit there.

### Detecting the mode

The work-org identifier is **not** stored anywhere in this repository. It comes from the runtime environment, which the user's shell loads from a secret manager.

1. Read the work-org marker from `$WORK_COMPANY` (env var). If it's unset, empty, or whitespace → **suggest-only mode** for this repo. Do not warn loudly; one short line is enough.
2. Read the repo's primary remote: `git remote get-url origin` (fallback to the first remote if `origin` is missing). Lowercase it.
3. If the remote URL contains the value of `$WORK_COMPANY` (case-insensitive substring) → **work mode**. Otherwise → **suggest-only mode**.
4. Announce the mode in one short line before showing the message, e.g. `mode: work (matched remote)` or `mode: suggest-only`. Do **not** echo the marker value or any other secret env contents back to the user — they're private.

If `$WORK_COMPANY` is available, `$WORK_MAIN_PROJECT` usually is too — you may use it (case-insensitive) as a hint when guessing scope, but never print it back.

## Steps

1. Run `git status`. If there are no staged changes, stop and tell the user to stage files first. Do not stage on their behalf.
2. Determine the mode (see above).
3. **Hunk comment gate** (non-blocking — see below). Resolve unaddressed user review comments in a live hunk session before composing the commit.
4. Analyze the staged diff: `git diff --cached`.
5. Build the commit message (rules below).
6. **Suggest-only mode:**
   - Print the **raw** commit message exactly as it would be committed (no markdown fences, no commentary around it).
   - Add one short follow-up line: "Commit and push are up to you."
   - Stop. Do not run any git mutation command.
7. **Work mode, branch guard:** if `git rev-parse --abbrev-ref HEAD` is `main` or `master`, create a feature branch first:
   - `git checkout -b <type>/<scope>-<short-slug>` (e.g. `feat/<scope>-short-thing`).
   - Slug: lowercase, hyphens, short. Pick `type`/`scope` consistent with the commit you are about to make.
8. **Work mode, commit:** run `git commit` **only after the user explicitly asks to commit**. Output the message first for confirmation. Never run `git push`.

## Hunk comment gate (step 3)

Before composing the commit, check whether the user left inline review comments in a
live **hunk** session (the user reviews diffs in hunk and drops notes on lines worth
attention). This gate is **non-blocking and best-effort**:

1. `hunk session comment list --repo . --type user --json` (after confirming a session
   exists via `hunk session list --json`).
2. **No live session, or no user comments → say nothing of note and proceed** with the
   commit. This is the common case; do not nag.
3. **User comments exist → invoke the `hunk-comment-review` skill** to resolve them
   (edit code or reply inline) *before* writing the commit message, so the commit
   reflects the addressed feedback. Then continue.
4. The user can always override ("just commit") — honour it; the gate never blocks a
   commit the user explicitly asks for.

## Commit message rules

1. If `commitlint.config.js` exists in the repo root, read it and honour its `type-enum`, `scope-enum`, and `scope-empty` rules. Do not invent values that would fail commitlint.
2. If there is no `commitlint.config.js`, use plain conventional-commit defaults (`feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `build`, `ci`, `revert`). Scope is optional; infer from changed paths if it's obvious, otherwise omit.
3. Format: `type(scope): subject` plus optional body/footer.
4. **Subject:** all lowercase, imperative mood ("add endpoint", not "added"), no period at the end, no leading capital, ~72 chars max **before** the gitmoji.
5. **Compound scopes** (e.g. `a,b`) are allowed only if the project's `scope-enum` lists that combination. Otherwise pick one scope or split the work — never invent scopes that fail commitlint.
6. When outputting the final message for copy-paste, output **only** the raw message (no fences, no commentary around it). One blank line then the "commit and push are up to you" reminder in suggest-only mode is fine; nothing extra in work mode.
7. Never append `Co-Authored-By:` trailers, "🤖 Generated with Claude Code" footers, or any other AI signature. The commit body — if any — only carries actual change context.

## Gitmoji (end of subject line)

Append **one** Unicode emoji at the **end** of the first line, after a space, based on the primary `type`:

| type           | emoji |
|----------------|-------|
| feat           | ✨    |
| fix            | 🐛    |
| docs           | 📝    |
| chore          | 🔧    |
| tests / test   | ✅    |
| hotfix         | 🚑    |
| refactor       | ♻️    |
| perf           | ⚡    |
| build          | 📦    |
| ci             | 👷    |
| revert         | ⏪    |

Example first line: `fix(api): resolve session handling 🐛`

If the repo's commitlint or CI rejects non-ASCII characters, say so and offer the same message **without** the emoji.

## Execution (work mode only)

```bash
git commit -m "<type>(<scope>): <subject> <emoji>"
# or with body:
git commit -m "<type>(<scope>): <subject> <emoji>" -m "<body>"
```

Never run `git push`, never `--no-verify`, never bypass hooks. If a commit hook fails, surface the failure and let the user decide.
