---
description: Never create native Claude worktrees — Greg manages worktrees via `work`
alwaysApply: true
---

# Do Not Create Native Git Worktrees

Greg manages worktrees with his own `work` CLI (nushell over `workctl`: `work new/ls/switch/rm/pr`). Claude-made ones (`.claude/worktrees/agent-*`, `wf_*`) are clutter.

1. **No `isolation: "worktree"` and no `EnterWorktree`** (guard denies both); subagents run in the shared workspace. Dynamic workflows are off globally (`disableWorkflows: true`): don't route around it.
2. **A task that needs an isolated checkout uses `workctl`** or asks him.
3. His own `work`/tuios worktrees, and reading inside them, are fine; leave one you made in place when the task ends unless he asks otherwise.

## `work` is not callable from the Bash tool

It is a nushell function (zsh and the nushell MCP both say not found): don't retry or ask him to install anything. Call the binary from inside the repo:

```bash
workctl --branch <branch> [--base origin/<ref>] --action wt-full --yes --no-focus
```

Same path as `work new`: worktree at `~/Code/tree/wt-<repo>/<branch>`, a tuios session `<repo>-<branch>` with `nu` and `claude` workspaces, `node_modules` and `.env*` cloned (from the base's worktree when stacked), work skills placed. Works for new or existing branches and worktrees, with or without a PR; pass `--base` for a stacked branch.

- **Working on it yourself from this session → add `--no-claude`**, else an idle Claude pane sits in the sidebar on a worktree with changes. Say "worktree `<branch>`, pracuję z tego okna"; once its PR is open, close it with `workctl done` from the worktree.
- After `workctl` on an existing branch take the path from `git worktree list --porcelain | rg -B2 'refs/heads/<branch>$'`, not the naming convention, and never `cd` into an unchecked path (b5531ea1).
- **Fallback only where tuios is missing (the lab)**: `git worktree add -b <branch> ~/Code/tree/wt-<repo>/<branch> origin/main`, said in one line. It lacks the session, agent workspace, work skills, `.env*`, `node_modules`, `.husky/_` and built packages; the fixes are in `~/.claude/rules/work-local-stack.md` (`Read` it before the first commit in a worktree `workctl` didn't make).

## A fix gets its own worktree off `main`, before the first `Edit`

`git fetch origin main`, then `workctl --branch fix/<slug> --base origin/main --action wt-full --yes --no-focus`; test, commit and open the PR from there. Don't switch branches in place or cherry-pick back.

- **Decide at the start**: a standalone fix someone waits for → `workctl` before the first `Edit` (a commit popup onto the feature branch got "nie, zrób osobny branch i pr teraz").
- **The main checkout counts too**: `git checkout -b` there moves every other tuios agent onto your branch.
- **Already staged on the feature branch?** Move it as a patch: `git diff --cached > <scratch>/fix.patch && test -s <scratch>/fix.patch`, `git diff --stat HEAD origin/main -- <files>` (empty = identical on `main`), `workctl …`, `git apply --index <scratch>/fix.patch` in the new worktree, `git restore --staged --worktree <files>` in the old one (28875263).
