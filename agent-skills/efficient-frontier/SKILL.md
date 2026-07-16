---
name: efficient-frontier
description: >-
  Use when a task is token-heavy or parallelizable — broad codebase research,
  multi-file audits/migrations, wide test/debug sweeps, log reduction — and you
  want the expensive frontier model to stay on judgment while cheaper subagents
  do the bulk work. Delegate research, mechanical coding, and testing to
  subagents; keep planning, synthesis, and final review at the frontier. Ported
  from BuilderIO/skills → skills/efficient-frontier (standalone rewrite).
---

# Efficient Frontier

Spend the expensive frontier tokens where marginal judgment matters. Push
repeatable, bounded, or token-heavy work to cheaper/faster subagents.

In this harness that means the **Agent** tool (`model`/`effort`/`agentType`
overrides per call) and the **Workflow** tool (parallel/pipeline fan-out). Use a
cheaper `model` on delegated Agent calls; keep the orchestrating loop on the
frontier model.

## Workflow

1. Identify the frontier-only decisions: architecture, prioritization, ambiguity
   resolution, risk, synthesis, final review.
2. Identify delegable work: research scans, repo inventory, search, docs
   extraction, browser/testing passes, log reduction, test-failure clustering,
   narrow coding, mechanical edits.
3. Spawn parallel subagents for independent slices — clear ownership, bounded
   scope, verification gates, expected evidence. (Agent calls in one message, or
   a Workflow `parallel`/`pipeline`.)
4. Require compact returns: findings, changed files, commands run, residual
   risk, stop conditions hit, and anything the frontier model must decide. Prefer
   a `schema` on the Agent/agent() call so returns are structured.
5. Integrate and review centrally before presenting the result.

## Handoff Packets

Write delegated prompts as self-contained packets — assume the receiver hasn't
seen the conversation. Include: repo path, objective, scope, out-of-scope areas,
relevant files or search targets, expected return format, verification commands,
stop conditions.

Useful stop conditions:

- Live code doesn't match the assumption in the handoff.
- A verification command fails twice after a reasonable fix/retry.
- The work appears to need files outside the assigned scope.
- The agent can't produce concrete evidence for its claim.

## Review Loop

Treat delegated output as evidence to inspect, not a verdict to forward. Reopen
important cited files, skim high-risk diffs, rerun or spot-check the verification
that matters before claiming completion. If delegated agents disagree, resolve
it at the frontier layer.

## Common Scenarios (soft suggestions)

- **Research** — delegate broad repo scans, docs extraction, source comparison;
  frontier keeps the judgment about what matters.
- **Coding** — delegate bounded patches, refactors, mechanical edits when file
  ownership is clear (use `isolation: worktree` if they edit in parallel);
  integrate and review centrally.
- **Testing** — frontier picks the validation strategy; cheaper agents run unit
  checks, browser flows, screenshots, log reduction. Ask them to return exact
  commands, failures, likely causes, and whether the signal looks flaky,
  environmental, or product-relevant.
- **Debugging** — send independent agents after separate theories/logs/repros;
  keep the final diagnosis at the frontier.

## Guardrails

- Don't delegate the immediate blocker if your next step depends on it.
- Don't have multiple agents edit the same files at once (or isolate in worktrees).
- Don't trust subagent conclusions blindly when risk is high — inspect the
  important evidence yourself.
- Don't claim universal savings. This wins when exploration and
  implementation/testing/research can genuinely be parallelized; skip it for
  small, sequential, or tightly-coupled work.

## Default Framing

"Frontier model as orchestrator + reviewer; cheaper subagents for token-heavy
research, coding, or testing — so the expensive tokens go to judgment,
synthesis, and final quality."
