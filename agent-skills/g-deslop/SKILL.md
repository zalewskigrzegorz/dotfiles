---
name: deslop
description: Use when pending changes need AI-slop cleanup before they land in git — added comments, defensive bloat, any-casts, dead code, style inconsistent with the file. Invoked directly as /deslop, and mandatory as the pre-commit gate in g-commit work mode.
---

# deslop

Remove AI-generated slop from the changes you (or this branch) introduced. Never touch lines outside the diff.

## Scope — pick the smallest diff that covers the pending change

1. Staged changes exist → `git diff --cached` (pre-commit gate mode).
2. Otherwise dirty tree → `git diff HEAD`.
3. Otherwise clean tree on a branch → diff vs merge-base with `main`/`master`.

## What to remove (only on added/changed lines)

- **Comments a human wouldn't add**: narrating the next line, restating the diff, "why my change is correct" notes, section banners. In repos with a no-comment convention (the work monorepo) every added comment goes, unless it's a machine directive (`eslint-disable`, `@ts-expect-error`, `prettier-ignore`, `istanbul ignore`) carrying its reason.
- **Defensive checks or try/catch abnormal for that area** of the codebase, especially on trusted/validated codepaths.
- **Casts to `any`** (or equivalent) to get around type issues — fix the type or surface the problem instead.
- **Dead additions**: unused imports/vars/helpers, commented-out code, leftover `console.log`/debug prints.
- **Any other style inconsistent with the file**: naming, structure, abstraction level, error handling.

## After editing

1. If files were staged, re-stage exactly the files you edited (`git add <files>`) so the cleaned version is what gets committed.
2. Report a 1–3 sentence summary of what was removed. "No slop found" is a valid result — but only after actually reading the diff.
