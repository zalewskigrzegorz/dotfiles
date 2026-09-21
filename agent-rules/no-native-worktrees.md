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
