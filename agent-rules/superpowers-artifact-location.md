---
description: Superpowers plans/specs/brainstorms always go to the bazgroly repo, never inside any project repo
alwaysApply: true
---

# Superpowers Artifact Location

Plans, specs, brainstorm notes, design docs and any other meta-artifacts produced by the `superpowers` plugin skills (`brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, etc.) **always** live in the dedicated `bazgroly` repo. They are NEVER saved into the repo the user is currently working in — not into work repos, not into personal repos, not into `dotfiles`, not into anything.

This overrides the default save locations in those skills (`docs/superpowers/plans/...`, `docs/superpowers/specs/...`).

## Why

AI scratch artifacts pollute diffs, PRs and history in any repo that has its own purpose. Even in personal repos (like `dotfiles`) they clutter the working tree. `bazgroly` is the single private GitHub repo that exists specifically to hold these artifacts — versioned, searchable, separated from project code.

## Where to save artifacts

Always:

```
~/Code/personal/bazgroly/<repo-basename>/
├── plans/YYYY-MM-DD-<feature>.md
├── specs/YYYY-MM-DD-<topic>-design.md
└── brainstorm/YYYY-MM-DD-<topic>.md
```

`<repo-basename>` = the basename of the repo root the user is currently working in (e.g. `dotfiles`, `redocly-cms`, `reunite`, `realm`). If the user is not inside a git repo, use `scratch/` or another descriptive folder. Create the directory if missing — never refuse the skill, just relocate.

`bazgroly` lives at `github.com/zalewskigrzegorz/bazgroly` (private). Working tree: `~/Code/personal/bazgroly/`. The `PostToolUse` hook `~/.claude/hooks/bazgroly-autopush.sh` auto-commits + pushes to `origin/master` after every Write/Edit under that path — you do not need to commit by hand.

## Detection rules

Before writing any plan/spec/brainstorm/design file:

1. Resolve the current repo root with `git rev-parse --show-toplevel` (or use cwd basename if not in a repo).
2. Write to `~/Code/personal/bazgroly/<repo-basename>/{plans,specs,brainstorm}/...` — **never** inside the resolved repo.
3. Mention the chosen path in the response so the user can redirect if needed.

## Never

- Never `git add` a superpowers artifact in any project repo, even if it was created there by mistake — move it out (to `~/Code/personal/bazgroly/<repo-basename>/...`) and remove the in-repo copy.
- Never include superpowers artifacts in a commit or PR.
- Never silently relocate without telling the user where the artifact went.
- Never bypass the autopush hook (`--no-verify` etc.). If it fails, fix it.
- Never re-introduce a `docs/superpowers/` directory anywhere.
