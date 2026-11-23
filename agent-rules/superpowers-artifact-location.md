---
description: Every AI-generated scratch artifact (plan, spec, brainstorm, analysis, audit, research note, design doc) lives in the bazgroly repo. Only human-facing docs (README, CHANGELOG, in-repo docs/ trees, etc.) stay in the project repo.
alwaysApply: true
---

# AI Artifact Location

**Every AI-generated meta-artifact lives in the `bazgroly` repo**, never in the repo you work in. This overrides the default save locations of `superpowers:writing-plans`, `brainstorming`, `executing-plans`, `subagent-driven-development` and any ad-hoc file.

- **In scope (→ bazgroly)**: plans, specs, design docs, architecture notes, brainstorms, option comparisons, decision logs, analyses, audits, research notes, code reviews written as files, investigation notes, debugging timelines, AI post-mortems, any scratch markdown made to organize your reasoning, hand copies of Plan Mode exports.
- **Out of scope (→ project repo)**: `README.md`, `CHANGELOG.md`, `LICENSE`, `CONTRIBUTING.md`, shipped docs dirs (`docs/`, `apps/*/docs/`), code comments and docstrings, commit/PR/issue bodies, config, source, tests, anything for the product's human readers.
- The test: **would a teammate notice if this file disappeared from the project repo?** Yes → project; no → bazgroly.
- "Zanotuj pomysł, obrabiamy później" → a `notes/` file in his words, then pros and cons, a visual or a send only after his "kk"; no `superpowers:brainstorming`, the goal is known (e4228afc).

## Where and how

Path: `~/Code/personal/bazgroly/<repo-basename>/{plans,specs,brainstorm,analysis,notes}/YYYY-MM-DD-<topic>.md` (specs: `-<topic>-design.md`). `<repo-basename>` = basename of `git rev-parse --show-toplevel`; outside a repo `scratch/` or another descriptive folder. Create the dir if missing, never refuse. Say the chosen path in the reply.

Remote: `github.com/zalewskigrzegorz/bazgroly` (private). `~/.claude/hooks/bazgroly.sh` auto-stages on Edit/Write and squash-commits + pushes on Stop: no manual commit, never bypass it (`--no-verify`); if it fails, fix it.

A spec or plan Greg must approve opens at once with `plannotator annotate <file> --gate` (the MCP tool fails on CC 2.1.326, plannotator#3578). `Approved` = go-ahead, `Feedback` = revise and reopen (d709807a).

## Never

- `git add` an AI artifact in a project repo or put one in its commit/PR; one created there by mistake moves to bazgroly and the in-repo copy goes. No silent relocation, no `docs/superpowers/` directory anywhere.
- **A connection string with credentials** (`postgres://user:pass@host/…`) in **any** file (plan, spec, agent brief for tuios/`workctl`/`tuios start-agent`, notes, scratch script), even local dev defaults: bazgroly is on GitHub and the secret-scan hook blocks the whole write. Point at the file ("`DATABASE_URL` from `packages/database/.env.example`") or use `$DATABASE_URL`.
- **Getting round a `scan-secrets` block**: the hook wins, even in YOLO. No assembling the file from pieces or writing it with `node` (86abd453). Use a point `Edit` on lines without the secret; when a fixture itself must carry one, ask Greg once. A fake connection string or an existing secret constant in code is blocked the same.
