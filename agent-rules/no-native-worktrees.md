---
description: Never create native Claude worktrees — Greg manages worktrees via `work`
alwaysApply: true
---

# Do Not Create Native Git Worktrees

Greg manages git worktrees himself through his own `work` CLI (a nushell
function over `workctl`: `work new/ls/switch/rm/pr`). Worktrees that Claude Code creates on its own — the
`.claude/worktrees/agent-*` and `.claude/worktrees/wf_*` directories — are pure
clutter to him and must not be produced.

## Rules

1. **No `isolation: "worktree"` and no `EnterWorktree`.** The `guard` mod
   denies both; run subagents in the shared workspace.
2. Dynamic workflows are disabled globally (`disableWorkflows: true`) — do not
   route around that.
3. **If a task genuinely needs an isolated checkout, use `workctl`** (his
   tooling, below), or ask him — do not reach for native worktree isolation.
4. This is about *Claude-created* worktrees only. Greg's own `work`/tuios
   worktrees, and reading/searching inside them, are entirely fine.

## `work` is not callable from the Bash tool

`work` is a nushell function, not a binary on `PATH`. The Bash tool
runs zsh and reports `command not found: work`; the nushell MCP fails the same
way (`Command \`work\` not found`). Don't retry it and don't ask Greg to install
anything — his own shell has it, yours doesn't.

`work new` is a thin wrapper over **`workctl`**, and `workctl` is a binary on
`PATH`. Call it directly, from inside the repo:

```bash
workctl --branch <branch> [--base origin/<ref>] --action wt-full --yes --no-focus
```

That is the same path `work new` takes: the worktree in his layout
(`~/Code/tree/wt-<repo>/<branch>`), a tuios session `<repo>-<branch>` with the `nu` and `claude`
workspaces, `node_modules` and `.env*` cloned (from the base's worktree for a stacked
branch), and the work skills placed. It works for a new branch, an existing
branch and an existing worktree, with or without a PR. `--base` defaults to
`origin/<default>`; pass it for a stacked branch.

Plain `git worktree add -b <branch> ~/Code/tree/wt-<repo>/<branch> origin/main`
is the fallback only where tuios is missing (the lab). It leaves a bare checkout
with no session, no agent workspace and no `node_modules`. On 2026-09-29 a worktree
made that way had to be reopened by hand through the multiplexer's worktree
command (then herdr's, `tuios worktree new` has the same gap), the layout and
the seed, and Greg asked for the `workctl` path. Say in one line when you
fall back. An unseeded worktree misses work skills, `.env*`, `node_modules`,
`.husky/_` and built packages: the seven gaps and their fixes are in
`~/.claude/rules/work-local-stack.md` (loads with monorepo files; `Read` it
before the first commit in a worktree `workctl` did not make).

A worktree made either way is one of Greg's, not a Claude-managed one, so rule 4
covers it: leave it in place when the task ends unless he asks otherwise.
After `workctl` on an existing branch take the path from `git worktree list
--porcelain | rg -B2 'refs/heads/<branch>$'`, not from the `wt-<repo>/<branch>`
convention, and don't `cd` into an unchecked path (b5531ea1).

## A fix gets its own worktree off `main` — before the first `Edit`

`git fetch origin main`, then `workctl --branch fix/<slug> --base origin/main
--action wt-full --yes --no-focus`, then test, commit and open the PR from that
worktree. Don't switch branches in place and don't cherry-pick back.

- **Decide at the start, not at commit time.** A standalone fix someone is
  waiting for → `workctl` before the first `Edit` (a commit popup onto the
  feature branch got "nie, zrób osobny branch i pr teraz", d3a33909).
- **The main checkout counts too.** A session on a clean `main` in the shared
  main checkout still goes through `workctl`: `git checkout -b` there moves
  every other tuios agent onto your branch (02be04c1).
- **Already staged on the feature branch?** Move it as a patch:
  `git diff --cached > <scratch>/fix.patch && test -s <scratch>/fix.patch`,
  `git diff --stat HEAD origin/main -- <files>` (empty = files identical on
  `main`), `workctl …`, then `git apply --index <scratch>/fix.patch` in the new
  worktree and `git restore --staged --worktree <files>` in the old one
  (28875263, merged in 3 days).
