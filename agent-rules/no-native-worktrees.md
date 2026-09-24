---
description: Never create native Claude worktrees — Greg manages worktrees via `work`
alwaysApply: true
---

# Do Not Create Native Git Worktrees

Greg manages git worktrees himself through his own `work` CLI (herdr-native:
`work new/ls/switch/rm/pr`). Worktrees that Claude Code creates on its own — the
`.claude/worktrees/agent-*` and `.claude/worktrees/wf_*` directories — are pure
clutter to him and must not be produced.

## Rules

1. **Never pass `isolation: "worktree"`** to the Agent/Task tool or `isolation:
   'worktree'` to Workflow `agent()` calls when working in Greg's repos. Run
   subagents in the shared workspace instead.
2. **Never call `EnterWorktree`** or otherwise spin up a Claude-managed worktree.
   Dynamic workflows are already disabled globally (`disableWorkflows: true` in
   settings) — do not try to route around that.
3. **If a task genuinely needs an isolated checkout, use `work new <branch>`**
   (his tooling), or ask him — do not reach for native worktree isolation.
4. This is about *Claude-created* worktrees only. Greg's own `work`/herdr
   worktrees, and reading/searching inside them, are entirely fine.

## `work` is not callable from the Bash tool

`work` is a herdr-native shell function, not a binary on `PATH`. The Bash tool
runs zsh and reports `command not found: work`; the nushell MCP fails the same
way (`Command \`work\` not found`). Don't retry it and don't ask Greg to install
anything — his own shell has it, yours doesn't.

When a task needs a worktree and `work` is unreachable, create it with plain git
**in his layout**, which is `~/Code/tree/wt-<repo>/<branch>`:

```bash
git worktree add -b <branch> ~/Code/tree/wt-<repo>/<branch> origin/main
```

Read the exact layout off `git worktree list` in the repo first rather than
assuming it — that command shows where his existing worktrees live. Branch from
`origin/main`, never from the current HEAD, and say in one line that you used
git directly because `work` was not reachable.

A worktree made this way is one of Greg's, not a Claude-managed one, so rule 4
covers it: leave it in place when the task ends unless he asks otherwise.

## A worktree `work` did not seed is missing two things

`work` seeds every worktree it opens: `place-work-skills <path>` copies the
work-scoped skills (`g-pr`, `g-pr-review`, `g-github-issue`, …) into
`<path>/.claude/skills/`, and `work _seed-untracked` clones the gitignored
`.env*` files and `node_modules` from the parent checkout. A worktree made with
plain git — or a bare one Greg opened without seeding — has neither. On
2026-09-23 that meant `/g-pr` was not in the picker (the team's `pr` skill ran
instead and Greg had to stop it) and `pnpm start` died on a missing
`local/.env`.

So in the work monorepo, when `g-pr` is missing from the skill list or a
`.env` the task needs is missing, seed the worktree before going on:

```bash
place-work-skills <worktree>          # no-op outside the work monorepo
bash <worktree>/.claude/skills/worktree-dev/scripts/copy-env-from-main.sh
```

The second script is part of the `worktree-dev` skill that the first one places;
it copies only missing `.env` files from the main checkout and never prints them.
Then invoke the work skill — never fall back to the team's same-purpose skill
(`pr` instead of `g-pr`).
