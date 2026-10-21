---
description: Subagent model and effort follow the task's weight — Opus for code and long runs, Sonnet for mail and small items, Fable only on Greg's word
alwaysApply: true
---

# Subagent Model Follows the Task's Weight

Fable 5.1 is the interactive model for Greg's own session. It is **not** for
background work. On 2026-09-08 a research fan-out (1 supplement agent + 5 deep
agents, each spawning children) ran on Fable and burned 91% of the session
quota in under 20 minutes. On 2026-10-21 the opposite happened: every agent of
an orchestration day ran on Sonnet, code work included, and Greg asked for a
split by weight ("rzeczy związane z kodem i długie akcje odpalaj na opusie,
maile i małe itemy na sonecie, ustawiaj sam w zależności od wagi taska model i
effort").

## The table

| Task | Model | Effort |
|---|---|---|
| Code that lands in a PR, a migration, a multi-file refactor, a debugging hunt, anything expected to run > ~15 min | **Opus** (`--model opus`) | high |
| Code review draft of a non-trivial PR (security, data model, auth) | **Opus** | high |
| Mail drafts, Slack digests, transcript lookups, a config find, a one-file read-only check, a fan-out leaf | **Sonnet** (`--model sonnet`) | medium |
| Bulk mechanical work (search, scraping, JSON extraction, rename sweeps) | **Sonnet** | low |
| Anything, on Fable | only when Greg names Fable for that spawn, in the moment | — |

The orchestrator picks the row itself and says it in one line at spawn
("5 agentów: 2× Opus (PR, review), 3× Sonnet (maile, Slack)"). No popup for
the model unless the task sits between two rows.

## Rules

1. **Every `Agent` call and every `herdr agent start … -- --model <m>` names
   the model explicitly.** Never rely on inheritance or a skill's frontmatter —
   when the parent is Fable, inheritance means Fable. `subagent_type: "fork"`
   always inherits; don't fork bulk work.
2. **Never launch a subagent on Fable** unless Greg says so for that spawn, by
   name. "Odpal agenta" means the table above.
3. **Skills that spawn agents** (`research`, `research-deep`,
   `efficient-frontier`, `superpowers:dispatching-parallel-agents`,
   `superpowers:subagent-driven-development`, `superpowers:executing-plans`,
   `superpowers:requesting-code-review`, and any prompt template) inherit the
   table. "The most capable available model" in a skill is not an exception
   (2026-09-30: a whole-branch review ran on Fable because `executing-plans`
   said so).
4. **A review spawn where Greg may want depth** (final whole-branch review, a
   security judgement) still gets one `AskUserQuestion`: **Opus** (Recommended)
   · **Fable** (deeper, costs quota). Routine PR reviews take Opus from the
   table without asking. The `review-spawn-model.sh` hook turns a review spawn
   without that popup into a permission prompt naming the model.
5. **Before a fan-out, say the count and the models in one line** so Greg can
   stop it before it starts.
6. **The model is not the main cost — context re-reads are.** A
   `web-search-agent` re-reads every search result on every step: 37 steps
   burned 3.2 M cached tokens on Sonnet (2026-09-08). Cap research agents at
   ~15 web calls per question, forbid them from spawning children, and prefer a
   `herdr` pane (`herdr agent start … -- --model <m>`, visible argv, `/clear`
   between briefs) over the in-process Agent tool for anything longer than a
   few minutes.
7. **Stopping a parent does not stop its children.** After `TaskStop`, run
   `ListAgents` and kill every orphan; repeat until the list is empty. Report
   the count killed.
8. **A spawn that edits files leaves file modes alone.** One changed the mode
   of 9 hook files and the change nearly went into a commit (2026-10-12). The
   brief says "no `chmod`"; before staging, `git diff --summary | rg 'mode
   change'` must be empty.

## Why the split

Search, scraping and mechanical edits do not need frontier judgement, and a
mail draft that Greg reads before sending can afford a cheaper model. Code
that lands in a PR is reviewed by the team and shipped to customers; a wrong
root cause there costs a review round and a revert, which is more than the
Opus premium. Fable stays with Greg's own session: planning, synthesis, the
final answer.
