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
