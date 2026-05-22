---
description: Superpowers plans/specs/brainstorms must never land inside work repos — they go to the bazgroly repo
alwaysApply: true
---

# Superpowers Artifact Location

Plans, specs, brainstorm notes, design docs and any other meta-artifacts produced by the `superpowers` plugin skills (`brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, etc.) must NOT be committed to repositories that are not personally owned by the user.

This overrides the default save locations in those skills (`docs/superpowers/plans/...`, `docs/superpowers/specs/...`).

## Why

Work repositories (REDACTED_ORG and any other org-owned repo) do not accept AI scratch artifacts. Committing brainstorm notes, plans, or design docs from `superpowers` into them pollutes diffs, PRs and history. But those artifacts still have value, so they live in a single private GitHub repo — `bazgroly` — versioned, but separated from project code.

## Where to save artifacts

Default for **any repo that is not explicitly a personal repo**:

```
~/Code/personal/bazgroly/<repo-basename>/
├── plans/YYYY-MM-DD-<feature>.md
├── specs/YYYY-MM-DD-<topic>-design.md
└── brainstorm/YYYY-MM-DD-<topic>.md
```

`<repo-basename>` = the basename of the repo root (e.g. `REDACTED_ORG-cms`, `reunite`, `realm`). Create the directory if missing — never refuse the skill, just relocate.

`bazgroly` lives at `github.com/zalewskigrzegorz/bazgroly` (private). Working tree: `~/Code/personal/bazgroly/`. The `PostToolUse` hook `~/.claude/hooks/bazgroly-autopush.sh` auto-commits + pushes to `origin/master` after every Write/Edit under that path — you do not need to commit by hand.

## Personal repos (default save location is allowed)

The following repos may use the skill's default in-repo paths (`docs/superpowers/...`):

- `~/Code/dotfiles`
- any repo under `~/Code/personal/` **except `bazgroly` itself** (bazgroly is the artifact destination, not a regular personal repo)
- any repo whose `origin` remote URL is under `github.com/Grzechu-AI/` or a personal namespace the user confirms

If unsure whether a repo counts as personal, ASK the user once and remember the answer for the session — do not assume.

## Detection rules

Before writing any plan/spec/brainstorm file:

1. Resolve the repo root with `git rev-parse --show-toplevel`.
2. If the path matches a personal-repo rule above → default location (`docs/superpowers/...`) is fine.
3. Otherwise → write to `~/Code/personal/bazgroly/<repo-basename>/...`.
4. In both cases, mention the chosen path in the response so the user can redirect.

## Never

- Never `git add` a superpowers artifact in a non-personal repo, even if it was created there by mistake — move it out (to `~/Code/personal/bazgroly/<repo-basename>/...`) and remove the in-repo copy.
- Never include superpowers artifacts in a commit or PR for a non-personal repo.
- Never silently relocate without telling the user where the artifact went.
- Never bypass the autopush hook (`--no-verify` etc.). If it fails, fix it.
