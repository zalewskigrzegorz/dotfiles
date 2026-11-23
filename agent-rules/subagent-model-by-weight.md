---
description: Subagent model and effort are computed from the task's measurable complexity before the spawn — no popup, no re-deriving, no switching on a running agent
alwaysApply: true
---

# Subagent Model and Effort Follow the Task's Complexity

Fable 5.1 is for Greg's own interactive session (a Fable research fan-out burned 91% of quota in 20 min); code and long tasks don't belong on Sonnet either. Greg: "rzeczy związane z kodem i długie akcje odpalaj na opusie, maile i małe itemy na sonecie, ustawiaj sam w zależności od wagi taska model i effort … nie chcę za każdym razem tego przeliczać".

## Score from the brief, then pick, before the spawn

| Signal in the brief | Points |
|---|---|
| Writes code that lands in a PR (fix, feature, migration, refactor) | +3 |
| Touches >1 package or app, or a schema / migration / auth path | +2 |
| Expected to run >~15 min (build, e2e, debugging hunt, multi-step flow) | +2 |
| Argues a position with evidence (review of a non-trivial PR, design objection) | +2 |
| Needs repo history (`git log -S`, blame, "why is it like this") | +1 |
| Read-only lookup with a known source; draft Greg reads first; bulk mechanical work | 0 |

| Score | Model | Effort |
|---|---|---|
| 0–1 | Sonnet | low for bulk, medium otherwise |
| 2–3 | Sonnet | high |
| ≥ 4 | Opus | high |
| Fable | only when Greg names it for that spawn | — |

E.g. a Slack digest or dealer mail 0 → Sonnet medium; a PR review merging two team tables (+2 argue, +2 schema, +1 history) → Opus high; a UI filter fix +3 → Sonnet high (+2 if it touched the API → Opus).

## Rules

1. **Every spawn names the model** (`Agent(model: …)`, `tuios start-agent … -- --model <m>`; guard denies a spawn without one) and the spawn line states the score: "PR review #31204: 5 pkt → Opus high". Never rely on inheritance or a skill's frontmatter; `subagent_type: "fork"` always inherits, so no forks for bulk work.
2. **Decide once. Never `/model` on a running agent**; a task that outgrows its score finishes on its model, the overrun goes into the next brief's score.
3. **No popup for the model**; the score answers it.
4. **Skills that spawn agents score the same way** (`research`, `research-deep`, `efficient-frontier`, `superpowers:*` dispatch/execute/review skills, any prompt template); "the most capable available model" in a skill is no exception.
5. **Before a fan-out, one line with count, models and ETA** ("5 agentów: 2× Opus, 3× Sonnet, ~15 min").
6. **Context re-reads cost more than the model**: a `web-search-agent` burned 3.2 M cached tokens in 37 steps. Cap research agents at ~15 web calls per question, forbid children, and prefer a `tuios` window (visible argv, `/clear` between briefs) over the in-process Agent tool for anything longer than a few minutes.
7. **Stopping a parent does not stop its children**: after `TaskStop`, `ListAgents` and kill every orphan until empty; report the count.
8. **A spawn that edits files leaves file modes alone**: the brief says "no `chmod`", and `git diff --summary | rg 'mode change'` is empty before staging.
