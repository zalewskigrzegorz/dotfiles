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
3. **If a task genuinely needs an isolated checkout, use `workctl`** (his
   tooling, below), or ask him — do not reach for native worktree isolation.
4. This is about *Claude-created* worktrees only. Greg's own `work`/herdr
   worktrees, and reading/searching inside them, are entirely fine.

## `work` is not callable from the Bash tool

`work` is a herdr-native shell function, not a binary on `PATH`. The Bash tool
runs zsh and reports `command not found: work`; the nushell MCP fails the same
way (`Command \`work\` not found`). Don't retry it and don't ask Greg to install
anything — his own shell has it, yours doesn't.

`work new` is a thin wrapper over **`workctl`**, and `workctl` is a binary on
`PATH`. Call it directly, from inside the repo:

```bash
workctl --branch <branch> [--base origin/<ref>] --action wt-full --yes --no-focus
```

That is the same path `work new` takes: the worktree in his layout
(`~/Code/tree/wt-<repo>/<branch>`), a herdr workspace with the `nu` and `claude`
tabs, `node_modules` and `.env*` cloned (from the base's worktree for a stacked
branch), and the work skills placed. It works for a new branch, an existing
branch and an existing worktree, with or without a PR. `--base` defaults to
`origin/<default>`; pass it for a stacked branch.

Plain `git worktree add -b <branch> ~/Code/tree/wt-<repo>/<branch> origin/main`
is the fallback only where herdr is missing (the lab). It leaves a bare checkout
with no workspace, no agent tab and no `node_modules`. On 2026-09-29 a worktree
made that way had to be reopened by hand through `herdr worktree open`, the
layout and the seed, and Greg asked for the herdr path. Say in one line when you
fall back.

A worktree made either way is one of Greg's, not a Claude-managed one, so rule 4
covers it: leave it in place when the task ends unless he asks otherwise.

## A worktree `work` did not seed is missing five things

`work` seeds every worktree it opens: `place-work-skills <path>` copies the
work-scoped skills (`g-pr`, `g-pr-review`, `g-github-issue`, …) into
`<path>/.claude/skills/`, and the seed step clones the gitignored `.env*` and
`*.env.json` files, `node_modules` and `.husky/_` from the parent checkout. A worktree made
with plain git — or a bare one Greg opened without seeding — has none. On
2026-09-23 that meant `/g-pr` was not in the picker (the team's `pr` skill ran
instead and Greg had to stop it) and `pnpm start` died on a missing
`local/.env`. On 2026-09-25 and 09-28 a missing `.husky/_` made every commit
fail on `.husky/_/husky.sh: No such file or directory`; earlier commits on the
branch had skipped lint-staged, which surfaced later as a red `oxfmt --check`
in CI. The fix is `pnpm install --config.confirmModulesPurge=false` in the
worktree (~40 s, no `./install.sh`), never `--no-verify`. The flag matters:
pnpm 11 asks before purging modules, the Bash tool has no TTY, and a bare
`pnpm install` dies with "If you are running pnpm in CI, set …
confirmModulesPurge to false" (2026-10-01). Don't reach for `CI=true`
instead, it also changes lockfile behaviour.

A fourth gap: **built workspace packages.** vitest in a fresh worktree failing
with `ERR_MODULE_NOT_FOUND` / `Cannot find package '@<org>/<pkg>'` means the
workspace packages it imports were never built there. Run the `nx` target of
the package under test once (`pnpm exec nx run <project>:ts:check`, 3–6 min,
in the background) before the first test run. `pnpm install` does not fix it
(2026-09-30).

A fifth gap: **the e2e config `playwright.env.json`.** It is gitignored and
sits next to the e2e suite (`e2e/*/playwright.env.json`), so an unseeded tree
fails with `Failed to find .rc file at …/playwright.env.json` (2026-10-04).
`workctl` clones `*.env.json` since 2026-10-06; for an older worktree, `cp -c
<main checkout>/<same path> <worktree>/<same path>`, without printing it.

**Check the worktree at the start of the session, not when a skill misfires.**
In any `~/Code/tree/wt-*` path: `.claude/skills/g-pr` missing → run
`place-work-skills <worktree>` before any PR skill. Skills placed while a
session is already running may not show up in the picker; if `/g-pr*` still
says "Unknown command", `/exit` and `claude --continue`.

So in any work repo (`~/Code/<Org>/*` or a remote in the work org), when `g-pr`
is missing from the skill list or a `.env` the task needs is missing, seed the
worktree before going on:

```bash
place-work-skills <worktree>          # no-op outside work repos
bash <worktree>/.claude/skills/worktree-dev/scripts/copy-env-from-main.sh
```

The second script is part of the `worktree-dev` skill that the first one places;
it copies only missing `.env` files from the main checkout and never prints them.
Then invoke the work skill — never fall back to the team's same-purpose skill
(`pr` instead of `g-pr`).

## A hotfix found on a feature branch gets its own worktree off `main`

`git fetch origin main`, then `workctl --branch fix/<slug> --base origin/main
--action wt-full --yes --no-focus`, then test, commit and open the PR from that
worktree. Don't switch branches in place and don't cherry-pick back: the
feature branch stays clean (2026-10-01, SCIM hotfix split off `feat/…`, merged
the same day).
