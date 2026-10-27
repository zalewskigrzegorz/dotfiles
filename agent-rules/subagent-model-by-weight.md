---
description: Subagent model and effort are computed from the task's measurable complexity before the spawn — no popup, no re-deriving, no switching on a running agent
alwaysApply: true
---

# Subagent Model and Effort Follow the Task's Complexity

Fable 5.1 is the interactive model for Greg's own session, not for background
work (2026-09-08: a research fan-out on Fable burned 91% of the quota in 20
min). On 2026-10-21 the opposite happened: nine agents of an orchestration day
ran on Sonnet, code included. Greg's rule, verbatim: "rzeczy związane z kodem i
długie akcje odpalaj na opusie, maile i małe itemy na sonecie, ustawiaj sam w
zależności od wagi taska model i effort", and the same day: "to są wymierne
dane, nie chcę za każdym razem tego przeliczać, zastanawiać się albo zmieniać
już na agencie działającym".

## Score the task, then pick — before the spawn

Count the points from what the brief already says. No judgement call, no
popup; the score is stated in the spawn line.

| Signal in the brief | Points |
|---|---|
| Writes code that lands in a PR (fix, feature, migration, refactor) | +3 |
| Touches more than one package or app, or a schema / migration / auth path | +2 |
| Expected to run longer than ~15 min (build, e2e, a debugging hunt, a multi-step flow) | +2 |
| Argues a position with evidence (a review of a non-trivial PR, a design objection) | +2 |
| Needs the repo's history to answer (`git log -S`, blame, "why is it like this") | +1 |
| Read-only lookup with a known source (a Slack thread, a mail thread, a config value) | 0 |
| Draft that Greg reads before it goes out (mail, Slack reply, form) | 0 |
| Bulk mechanical work (search, scrape, rename sweep, JSON extraction) | 0 |

| Score | Model | Effort |
|---|---|---|
| 0–1 | Sonnet (`--model sonnet`) | low for bulk, medium otherwise |
| 2–3 | Sonnet | high |
| ≥ 4 | Opus (`--model opus`) | high |
| any, Fable | only when Greg names Fable for that spawn, in the moment | — |

Examples from 2026-10-21: a Slack digest (0 → Sonnet medium), a mail draft to
a dealer (0 → Sonnet medium), a refresh-token TTL lookup with a diff sketch
(+1 history → Sonnet medium), a review of a PR that merges two team tables
(+2 argue, +2 schema, +1 history → Opus high), a People-page filter fix in
`apps/ui` (+3 PR → Sonnet high, borderline; +2 if it had touched the API →
Opus).

## Rules

1. **Every spawn names the model explicitly** — `Agent(model: …)` or `tuios
   start-agent … -- --model <m>` — and the spawn line states the score: "PR
   review #31204: 5 pkt → Opus high". Never rely on inheritance or a skill's
   frontmatter; when the parent is Fable, inheritance means Fable.
   `subagent_type: "fork"` always inherits, so no forks for bulk work.
2. **Decide once, before the spawn. Never `/model` on a running agent.**
   A task that grows past its score mid-run finishes on the model it started
   on; the overrun goes into the next brief's score, not into a switch.
3. **No popup for the model.** The score answers it. The only exception is
   Greg naming Fable himself. The `review-spawn-model.sh` hook, which turned
   a review spawn into a permission prompt, is retired with this rule.
4. **Skills that spawn agents** (`research`, `research-deep`,
   `efficient-frontier`, `superpowers:dispatching-parallel-agents`,
   `superpowers:subagent-driven-development`, `superpowers:executing-plans`,
   `superpowers:requesting-code-review`, and any prompt template) score the
   same way. "The most capable available model" in a skill is not an
   exception (2026-09-30: a whole-branch review ran on Fable because
   `executing-plans` said so).
5. **Before a fan-out, one line with count, models and ETA** ("5 agentów: 2×
   Opus, 3× Sonnet, ~15 min") so Greg can stop it before it starts.
6. **The model is not the main cost — context re-reads are.** A
   `web-search-agent` re-reads every result on every step: 37 steps burned
   3.2 M cached tokens on Sonnet (2026-09-08). Cap research agents at ~15 web
   calls per question, forbid them from spawning children, and prefer a
   `tuios` window (visible argv, `/clear` between briefs) over the in-process
   Agent tool for anything longer than a few minutes.
7. **Stopping a parent does not stop its children.** After `TaskStop`, run
   `ListAgents` and kill every orphan; repeat until the list is empty. Report
   the count killed.
8. **A spawn that edits files leaves file modes alone.** One changed the mode
   of 9 hook files and the change nearly went into a commit (2026-10-12). The
   brief says "no `chmod`"; before staging, `git diff --summary | rg 'mode
   change'` must be empty.

## Why a score

Search, scraping and a draft Greg reads before sending do not need frontier
judgement. Code that lands in a PR is reviewed by the team and shipped; a
wrong root cause there costs a review round and a revert, more than the Opus
premium. The score makes that trade once, in numbers, so no session re-derives
it and no running agent gets switched halfway.
