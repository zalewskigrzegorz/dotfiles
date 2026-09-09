---
description: Subagents always run on Sonnet, never on Fable 5.1 — quota protection
alwaysApply: true
---

# Subagents Run on Sonnet, Never on Fable

Fable 5.1 is the interactive model for Greg's own session. It is **not** for
background work. On 2026-09-08 a research fan-out (1 supplement agent + 5 deep
agents, each spawning children) ran on Fable and burned 91% of the session
quota in under 20 minutes.

## Rules

1. **Every `Agent` call passes `model: "sonnet"` explicitly.** Do not rely on
   the agent definition's frontmatter or on inheritance from the parent — when
   the parent is Fable, inheritance means Fable. The only exception is
   `subagent_type: "fork"`, which always inherits and ignores `model`; avoid
   forks for bulk work for the same reason.
2. **Never launch a subagent on Fable 5.1 or Opus** unless Greg says so in the
   moment, by name, for that specific spawn. "Odpal agenta" means Sonnet.
3. **Skills that spawn agents** (`research`, `research-deep`,
   `efficient-frontier`, `superpowers:dispatching-parallel-agents`,
   `superpowers:subagent-driven-development`, and any skill's prompt template)
   inherit this rule: add `model: "sonnet"` to each spawn even when the skill's
   template does not mention a model. The template's wording is a hard
   constraint on the *prompt*, not on the *model parameter*.
4. **Before a fan-out, say the count and the model in one line** ("5 agentów,
   Sonnet, ~10 min") so Greg can stop it before it starts.
5. **The model is not the main cost — context re-reads are.** A
   `web-search-agent` keeps every search result in its context and re-reads
   it on every step: 37 steps burned 3.2 M cached tokens on Sonnet
   (2026-09-08). Cap research agents at ~15 web calls per question, forbid
   them from spawning children, and prefer a `herdr` pane running
   `claude --model sonnet` (visible argv, `/clear` between briefs) over the
   in-process Agent tool for anything longer than a few minutes.
6. **Stopping a parent does not stop its children.** After `TaskStop`, run
   `ListAgents` and kill every orphan; repeat until the subagent list is empty.
   Report the count killed.

## Why Sonnet

Search, scraping, JSON-shaped extraction and mechanical edits do not need
frontier judgement. Keep Fable for planning, synthesis and the final answer to
Greg. That is the `efficient-frontier` split, applied by default and not only
when the skill is invoked.
