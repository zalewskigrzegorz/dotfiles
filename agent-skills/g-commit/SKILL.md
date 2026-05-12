---
name: g-commit
description: Creates a feature branch when on main/master, generates conventional commit messages from git diff --cached per commitlint, appends one gitmoji at end of subject, runs git commit via CLI. Use when the user wants to commit staged changes with project rules (REDACTED_ORG or repo-specific).
---

# g-commit

## When to use

User asks to commit staged changes, write a commit message, or align with commitlint / conventional commits.

## Language

All **generated** text (commit message subject/body) must be **English**, even if the conversation is in another language.

## Steps

1. Run `git status` and confirm there are staged changes. If nothing is staged, stop and tell the user to stage files first.
2. **Branch guard:** If the current branch is `main` or `master`, create a new branch before committing:
   - `git checkout -b <type>/<scope>-<short-slug>` (e.g. `fix/realm-api-key-middleware`, `feat/reunite-geo-lookup`).
   - Use `type` and `scope` that match the commit you are about to make. Slug: lowercase, hyphens, short.
3. Analyze changes with `git diff --cached` (same as `git diff --staged`).
4. Build the commit message.
5. Run `git commit` only after the user explicitly asks to commit; do not stage or commit without permission.

## Commit message rules

1. Read `commitlint.config.js` in the repo root if it exists. Use its `type-enum`, `scope-enum`, and `scope-empty` rules. If absent, use REDACTED_ORG defaults below.
2. **REDACTED_ORG defaults** (when no config): types `docs`, `tests`, `feat`, `fix`, `chore`, `hotfix`; scopes `reunite`, `realm`, `other`, `deps`, `deps-dev`; scope is **required** (non-empty).
3. Format: `type(scope): subject` plus optional body/footer.
4. **Subject:** all lowercase, imperative mood (e.g. "add endpoint", not "added"), no period at the end, no leading capital letter, ~72 chars max for the text before gitmoji.
5. **Compound scopes** (e.g. `realm,reunite`): only if they appear in the project’s `scope-enum` or docs; otherwise pick one allowed scope or split work—do not invent scopes that fail commitlint.
6. When outputting the message for copy-paste, output **only** the raw message (no markdown fences, no commentary around it).

## Gitmoji (end of subject line)

Append **one** Unicode emoji at the **end** of the first line, after a space, based on primary `type`:

| type   | emoji |
|--------|-------|
| feat   | ✨    |
| fix    | 🐛    |
| docs   | 📝    |
| chore  | 🔧    |
| tests  | ✅    |
| hotfix | 🚑    |

Example first line: `fix(realm): resolve api key session handling 🐛`

If the repo’s commitlint or CI rejects non-ASCII characters, say so and offer the same message **without** the emoji.

## Execution

```bash
git commit -m "<type>(<scope>): <subject> <emoji>" 
# or with body:
git commit -m "<type>(<scope>): <subject> <emoji>" -m "<body>"
```

## Type / scope hints (REDACTED_ORG-style)

| Change                         | type   | scope often      |
|--------------------------------|--------|------------------|
| New capability                 | feat   | reunite/realm/other |
| Bug fix                        | fix    | reunite/realm/other |
| Documentation                  | docs   | other or realm   |
| Production deps                | fix or chore | deps      |
| Dev-only deps                  | chore  | deps-dev         |
| Tests                          | tests  | other/reunite/realm |
| Small maintenance / config     | chore  | other            |
