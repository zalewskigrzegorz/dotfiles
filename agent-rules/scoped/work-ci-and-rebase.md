---
paths: "apps/**, packages/**, local/**, e2e/**, platform/**, nx.json, pnpm-workspace.yaml, docker-compose.yml"
---

# Work monorepo — CI, rebase, PR checks

## After a rebase or merge from `main`: run what CI runs, then push

Four red checks after a rebase (df44b632), and a 16-commit rebase with ~25
conflicted files lost a function, a `start.sh` block and a test path silently
(c333538c).

- Before the push: `pnpm exec nx run-many -t knip:check ts:check lint -p
  <project>` in the background; touched `*.db.spec.ts` on their own database
  (see the local Docker rule). Red locally = no push. "0 passed, skipped
  without a database" is not green.
- `<project>` is `jq -r .name apps/<app>/package.json`. `No tasks were run`
  and `Cannot find configuration for task` in the log are "nie uruchomione",
  not green, and `exit=0` from `; echo exit=$?` proves nothing (255f38c7).
- A change in a shared module (loader, provider, singleton, cache) → full
  `vitest run` of the package in the background before the first push
  (6a89b245).
- A Prisma migration after a rebase: `git ls-tree --name-only HEAD
  packages/database/prisma/migrations/ | tail -3`. Older than the newest on
  `main` → `git mv` it later. Check the commitlint scope against `origin/main`
  (2530cc32).
- A file `main` moved → `git grep` the old import path first.
- Rebase onto a moved `main` changed the lockfile → `pnpm install --frozen-lockfile`, then build `api-sdk` and `shared` via nx. Typecheck with `nx ts:check`, bare `tsc` OOMs (2b9de962).
- Lint changed files the way the hook does, before the first commit: `oxlint -c tooling/oxlint/oxlintrc-new-code.json --max-warnings=0 <files>`. Plain `oxlint <pkg>` is not that (683de0e6).
- ≥10 files resolved by hand → `git diff origin/main...HEAD --diff-filter=M
  -U0 | rg '^-[^-]'` (every removed line belongs to the change) and `git
  range-diff` against the old ref.
- Changed test files → the package's `ts:check` too: vitest does not
  type-check, and a PR sat red for a full e2e cycle on that (9adba92d).
- `git log --merges origin/main..HEAD` not empty → a rebase flattens those
  merges and drops their hand-resolved conflicts without a conflict. Back up
  the branch, build the target tree in a scratch `GIT_INDEX_FILE`, and after
  the rebase `git diff <target-tree> HEAD --stat`: every difference you did not
  mean is a lost change (three found in c0cc0722).

## Red check on a stacked branch → compare with the base first

Lint, knip or a spec red on a branch stacked on a non-main base: before
touching code, run `rg-base-head <pattern> [paths] --base origin/<base>` (or
the check itself on the base). Same hits on both → report in one line
("identyczne na base, nie nasze") and leave them.

A branch off `main` gets the same check: the failing files from the job log
against `git diff --name-only origin/main...HEAD`, then one `gh run list
--branch main --workflow <wf> -L 10 --json conclusion,headSha`. No overlap and
the job red on `main` too → "nie nasze, flak na main" and `gh run rerun
--failed`. A flaky `PendingInvites.test.tsx` cost ~60 calls before that
(c0cc0722). A green run on `main` proves a flake only if its log contains
that spec (`nx affected` may skip it). The same spec red on ≥2 foreign PRs is
not a rerun (2530cc32): `gh run list --workflow <wf> --status failure -L 8`, then `--log-failed | rg -c <spec>` per run.

A PR-only workflow red: check its `on:` trigger, `git archive origin/main <paths>` into scratch and run the same test. Same failure = red on `main`, find the culprit with `git log -S` (b58c114a).

`.claude/skills/*/SKILL.md` has a 1500-word prose limit in the docs linter that the bot's "All good" does not cover. Run the repo's linter config on the files and its `skill-length` rule, move extras to `references/` (b58c114a, 15c9041d).

## CI waits: more than `gh-run-wait` finds

- After `gh run rerun`, wait for the new attempt, not the old run id. The red badge of attempt 1 stays, so the status line names the attempt time and the job in progress (5cdaf331).
- **Before toggling `run_e2e`:** `gh pr view <n> --json
  mergeable,mergeStateStatus`. `CONFLICTING`/`DIRTY` → rebase first; GitHub
  does not run `pull_request` workflows on a conflicting PR, and two toggles
  waited ~30 min for nothing (c333538c). No run within ~3 min after the toggle
  is the same signal.
- **After any push (force too) to a PR with `run_e2e`** the label stays but
  may not fire on the new sha. In ~3 min `gh run list --commit <sha> --workflow
  e2e-pr.yml`. Empty → remove and re-add the label after a verified push,
  then `gh-run-wait e2e-pr.yml --sha <sha>` (5cdaf331, 94d308ee).
- **`gh-run-wait` on the wrong workflow waits the full 1800 s** (the PR runs
  `e2e-pr.yml`, not `e2e.yml`), and after a label swap on the same sha it can
  report the old run. No run in ~3 min → `gh run list --commit <sha> --json
  workflowName,conclusion` (cc69e8c9, bb4925d2).
- **A deploy Greg starts by hand** (prod, prodeu, lab): start the watcher in
  the same turn, `Monitor` on `gh-run-wait <workflow> --sha <sha>`, and say
  "czekam na run na `<sha>`". The run appearing is machine state, so this is
  not waiting for a human (9d7d10df: "i co obserwujesz?").

## `pnpm patch-commit` rewrites more of the lockfile than the patch

After `pnpm patch-commit`, `pnpm-lock.yaml` also had a `(patch_hash=…)` peer
suffix on `@better-auth/oauth-provider`, which was not patched; undoing it took
~6 calls (2026-10-09). Right after it: `git diff --stat pnpm-lock.yaml
pnpm-workspace.yaml patches/`, keep only the patched package's entries and its
`patchedDependencies` line, and restore the rest from `git show HEAD:<file>`.

## `gh api`: removing a requested reviewer

`DELETE …/pulls/<n>/requested_reviewers` wants both keys in the body;
`-f 'team_reviewers[]=<slug>'` alone answers `"reviewers" wasn't supplied`
(2026-10-02). Send JSON:
`printf '{"reviewers":[],"team_reviewers":["<slug>"]}' | gh api -X DELETE repos/<o>/<r>/pulls/<n>/requested_reviewers --input -`.

## Temporal specs are red in the sandbox by design

`libs/temporal-workflows/**/*.spec.ts` download Temporal's test server and the
sandbox has no network: `Failed to start ephemeral server: error sending
request`. A full api `vitest` run red only there, on that message, is one
sentence ("tylko temporal, brak sieci w sandboxie, CI to pokryje"). No hunt,
no rerun. Any other failure in those files is a normal failure.

## Sentry `search_issues` takes no `OR` / `AND`

`(team OR scim)` answers HTTP 400 "Boolean statements … are not supported".
Several terms = several calls in one turn (c0cc0722).
