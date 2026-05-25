---
description: Every AI-generated scratch artifact (plan, spec, brainstorm, analysis, audit, research note, design doc) lives in the bazgroly repo. Only human-facing docs (README, CHANGELOG, REDACTED_ORG/docs/, etc.) stay in the project repo.
alwaysApply: true
---

# AI Artifact Location

**All AI-generated meta-artifacts live in the dedicated `bazgroly` repo** — never inside the repo the user is currently working in. This applies to *every* file you generate that exists to capture AI thinking, planning, or analysis, regardless of which skill or tool produced it.

This overrides the default save locations of skills like `superpowers:writing-plans`, `superpowers:brainstorming`, `superpowers:executing-plans`, `superpowers:subagent-driven-development`, as well as any ad-hoc file you'd otherwise drop into the working repo.

## What counts as an AI artifact

In scope (→ bazgroly):

- Plans, specs, design docs, architecture notes
- Brainstorm notes, option comparisons, decision logs
- Analysis reports, audit summaries, research notes, code reviews written as files
- Investigation notes, debugging timelines, post-mortems for AI sessions
- Any "thinking made durable" — scratch markdown the AI produces to organize its own reasoning
- Plan Mode exports / copies if you mirror them by hand

Out of scope (→ project repo, as usual):

- `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`
- Project documentation directories that ship with the codebase (`docs/`, `REDACTED_ORG/docs/`, `apps/*/docs/`, etc.)
- Inline code comments, JSDoc, docstrings
- Commit messages, PR bodies, issue bodies
- Configuration files, source code, tests
- Anything intended for human readers as part of the product

The test: **"If this file disappeared from the project repo, would a teammate notice?"** If yes — it belongs in the project. If no — it belongs in bazgroly.

## Why

AI scratch artifacts pollute diffs, PRs and history in any repo that has its own purpose. Even personal repos (like `dotfiles`) clutter up fast. `bazgroly` is the single private GitHub repo dedicated to these artifacts — versioned, searchable, and separated from product code.

## Where to save artifacts

Always:

```
~/Code/personal/bazgroly/<repo-basename>/
├── plans/YYYY-MM-DD-<feature>.md
├── specs/YYYY-MM-DD-<topic>-design.md
├── brainstorm/YYYY-MM-DD-<topic>.md
├── analysis/YYYY-MM-DD-<topic>.md
└── notes/YYYY-MM-DD-<topic>.md
```

`<repo-basename>` = the basename of the repo root the user is currently working in (e.g. `dotfiles`, `REDACTED_ORG-cms`, `reunite`, `realm`). If the user is not inside a git repo, use `scratch/` or another descriptive folder. Create the directory if missing — never refuse, just relocate.

`bazgroly` lives at `github.com/zalewskigrzegorz/bazgroly` (private). Working tree: `~/Code/personal/bazgroly/`. The `PostToolUse` hook `~/.claude/hooks/bazgroly-autopush.sh` auto-commits + pushes to `origin/master` after every Write/Edit under that path — you do not need to commit by hand.

## Detection rules

Before writing any plan / spec / brainstorm / analysis / design / audit file:

1. Resolve the current repo root with `git rev-parse --show-toplevel` (or use cwd basename if not in a repo).
2. Ask: is this file for human readers of the project (README-class), or is it AI scratch (planning/analysis-class)? If the latter, route to bazgroly.
3. Write to `~/Code/personal/bazgroly/<repo-basename>/{plans,specs,brainstorm,analysis,notes}/...` — **never** inside the resolved repo.
4. Mention the chosen path in the response so the user can redirect if needed.

## Never

- Never `git add` an AI artifact in any project repo, even if it was created there by mistake — move it out (to `~/Code/personal/bazgroly/<repo-basename>/...`) and remove the in-repo copy.
- Never include AI artifacts in a commit or PR for the project repo.
- Never silently relocate without telling the user where the artifact went.
- Never bypass the autopush hook (`--no-verify`, etc.). If it fails, fix it.
- Never re-introduce a `docs/superpowers/` directory anywhere.
