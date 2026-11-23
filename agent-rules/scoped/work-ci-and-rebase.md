---
paths: "apps/**, packages/**, local/**, e2e/**, platform/**, nx.json, pnpm-workspace.yaml, docker-compose.yml"
---

# Work monorepo — CI, rebase, PR checks

## After a rebase or merge from `main`: run what CI runs, then push

A 16-commit rebase with ~25 conflicted files once lost a function, a `start.sh` block and a test path silently (c333538c).

- Before the push: `pnpm exec nx run-many -t knip:check ts:check lint -p <project>` in the background; touched `*.db.spec.ts` on their own database (`work-local-stack.md`). Red locally = no push; "0 passed, skipped without a database" is not green.
- `<project>` is `jq -r .name apps/<app>/package.json`. `No tasks were run` / `Cannot find configuration for task` mean "nie uruchomione", and `exit=0` from `; echo exit=$?` proves nothing.
- A change in a shared module (loader, provider, singleton, cache) → full `vitest run` of the package in the background before the first push.
- A Prisma migration after a rebase: `git ls-tree --name-only HEAD packages/database/prisma/migrations/ | tail -3`; older than the newest on `main` → `git mv` it later. Check the commitlint scope against `origin/main`.
- A file `main` moved → `git grep` the old import path first.
- Lockfile changed by the rebase → `pnpm install --frozen-lockfile`, then build `api-sdk` and `shared` via nx. Typecheck with `nx ts:check`; bare `tsc` OOMs.
- Lint changed files the way the hook does, before the first commit: `oxlint -c tooling/oxlint/oxlintrc-new-code.json --max-warnings=0 <files>` (plain `oxlint <pkg>` is not that).
- ≥10 files resolved by hand → `git diff origin/main...HEAD --diff-filter=M -U0 | rg '^-[^-]'` (every removed line belongs to the change) and `git range-diff` against the old ref.
- Changed test files → the package's `ts:check` too: vitest doesn't type-check (a PR sat red a full e2e cycle on that).
- `git log --merges origin/main..HEAD` not empty → a rebase flattens those merges and drops their hand-resolved conflicts silently. Back up the branch, build the target tree in a scratch `GIT_INDEX_FILE`, and after the rebase `git diff <target-tree> HEAD --stat`: every unintended difference is a lost change.

## Red check → is it ours?

- **Stacked branch:** before touching code, `rg-base-head <pattern> [paths] --base origin/<base>` (or the check itself on the base). Same hits on both → "identyczne na base, nie nasze", leave them.
- **Off `main`:** failing files from the job log vs `git diff --name-only origin/main...HEAD`, then `gh run list --branch main --workflow <wf> -L 10 --json conclusion,headSha`. No overlap and red on `main` too → "nie nasze, flak na main" and `gh run rerun --failed` (a flaky `PendingInvites.test.tsx` once cost ~60 calls). A green `main` run proves a flake only if its log contains that spec (`nx affected` may skip it).
- The same spec red on ≥2 foreign PRs is not a rerun: `gh run list --workflow <wf> --status failure -L 8`, then `--log-failed | rg -c <spec>` per run.
- A PR-only workflow red: check its `on:`, `git archive origin/main <paths>` into scratch and run the same test. Same failure = red on `main`; find the culprit with `git log -S`.
- `.claude/skills/*/SKILL.md` has a 1500-word prose limit in the docs linter that the bot's "All good" doesn't cover: run the repo's linter config and its `skill-length` rule, move extras to `references/`.

## CI waits

- After `gh run rerun`, wait for the new attempt, not the old run id (attempt 1's red badge stays); the status line names the attempt time and the job in progress.
- **Before toggling `run_e2e`:** `gh pr view <n> --json mergeable,mergeStateStatus`. `CONFLICTING`/`DIRTY` → rebase first: GitHub runs no `pull_request` workflows on a conflicting PR. No run ~3 min after the toggle is the same signal.
- **After any push (force too) to a PR with `run_e2e`** the label may not fire on the new sha. In ~3 min `gh run list --commit <sha> --workflow e2e-pr.yml`; empty → remove and re-add the label after a verified push, then `gh-run-wait e2e-pr.yml --sha <sha>`.
- **`gh-run-wait` on the wrong workflow waits the full 1800 s** (PRs run `e2e-pr.yml`, not `e2e.yml`), and after a label swap on the same sha it can report the old run. No run in ~3 min → `gh run list --commit <sha> --json workflowName,conclusion`.
- **A deploy Greg starts by hand** (prod, prodeu, lab): same turn, `Monitor` on `gh-run-wait <workflow> --sha <sha>` and "czekam na run na `<sha>`". That is machine state, not waiting for a human (9d7d10df).

## Smaller traps

- **`pnpm patch-commit`** also adds `(patch_hash=…)` suffixes to unpatched packages in `pnpm-lock.yaml`. Right after it: `git diff --stat pnpm-lock.yaml pnpm-workspace.yaml patches/`, keep only the patched package's entries and its `patchedDependencies` line, restore the rest from `git show HEAD:<file>`.
- **Removing a requested team reviewer:** `DELETE …/requested_reviewers` wants both keys (`-f 'team_reviewers[]=…'` alone → `"reviewers" wasn't supplied`): `printf '{"reviewers":[],"team_reviewers":["<slug>"]}' | gh api -X DELETE repos/<o>/<r>/pulls/<n>/requested_reviewers --input -`.
- **Temporal specs are red in the sandbox by design**: `libs/temporal-workflows/**/*.spec.ts` download a test server and the sandbox has no network (`Failed to start ephemeral server: error sending request`). Red only there, on that message → one sentence ("tylko temporal, brak sieci w sandboxie, CI to pokryje"), no hunt. Any other failure there is normal.
- **Sentry `search_issues` takes no `OR` / `AND`** (HTTP 400): several terms = several calls in one turn.
