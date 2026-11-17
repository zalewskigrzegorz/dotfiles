---
paths: "apps/**, packages/**, local/**, e2e/**, platform/**, nx.json, pnpm-workspace.yaml, docker-compose.yml"
---

# Work monorepo — local stack, database, worktree seed

Loads when a monorepo file is touched. The always-on part is `shared-local-docker.md`.

## Reading and seeding the local database

Read-only queries need no `shared-local-docker` check. Three lookups each cost two or three
tries (2026-10-09 … 10-12):

- **The Mac has no `psql`.** Always `docker exec "$co-postgres-1" psql -U
  myuser -d <db> -At -c "…"`, including `create database` for a spec's own
  database.
- **Prisma's table is `prisma._prisma_migrations`**, not `_prisma_migrations`:
  `select migration_name, finished_at from prisma._prisma_migrations order by
  finished_at desc limit 20`.
- **A Node check that needs `pg` runs from `apps/api`**; `packages/database`
  does not resolve it (`Cannot find module 'pg'`). A runner script for DB specs
  goes in the scratchpad, not the repo.
- **Postgres stopped by `pnpm stop` comes back with `docker compose -p <co> up
  -d --wait postgres`**, not `docker start` (`failed to start containers`).
  Before a `pnpm start`, note `docker ps --format '{{.Names}}'` so you know
  what to restore afterwards.
- **The first `pnpm start` in a fresh worktree builds images for ~25 min.**
  Run it in the background with `timeout 3000` (or none) and a `Monitor` on the
  log. `exit=124` from a shorter timeout means "read the log", not "retry".
- **DB specs need their own database, never `main`.** Point the spec's
  database URL at `db_specs` (or `create database` one). The password comes
  from the container, the URL is built inline in single quotes and never
  written to a file: `pw=$(docker exec "$co-postgres-1" printenv
  POSTGRES_PASSWORD)`, then `VAR='postgresql://myuser:'"$pw"'@localhost:5432/db_specs'
  pnpm exec vitest …`. Don't grep `.env` for it (~8 calls, 2026-10-15).
- **A migration test runs on a clone of `main`**, not a hand-built empty
  database: `docker exec "$co-postgres-1" sh -c 'createdb -U myuser <scratch> &&
  pg_dump -U myuser -d main --no-owner | psql -U myuser -d <scratch> -q -v
  ON_ERROR_STOP=1'`. Say "lokalnie, kopia `main` do `<scratch>`", drop it after;
  `already exists` there is another branch's leftover schema (a120142c, 3 tries).
  The clone's URL ends `?schema=prisma&sslmode=disable` (single quotes):
  `P3005` means that is missing, not a broken base. Before `better-auth`
  specs on the clone `delete from auth.jwks` there, never in `main` (symptom
  `Unexpected end of JSON input` on `/token`, 76d3b8f1).
- **colima has `mounts: []`** (`~/.colima/default/colima.yaml`): `-v <host
  dir>:/x` sees an empty path. Use `docker cp`, a volume or bake into the
  image (07921d16).
- **Handing the local stack to Greg:** last step `pnpm pm2 restart api
  auth-server temporal-worker`, `prisma._prisma_migrations` rows against the
  `prisma/migrations` dirs, `curl` on `/` (307) and the API. No `nx` on shared
  libraries during his test (76d3b8f1).
- **A fresh database needs the Ory schemas before Prisma.** `create schema
  kratos; create schema hydra`, the Ory migrations from the `oryd/hydra` image
  (DSN with `search_path=hydra`, same for kratos), then `prisma migrate
  deploy`. `P3009` on a fresh database means those schemas are missing, not a
  broken migration. Drop your own database when done (3 recreate cycles,
  2026-10-16).
- **Empty UI after `db:seed` → check Greg's membership first.** The seed only
  makes memberships for the seed user; Greg's account needs an `OWNER` row in
  the `default` org. Before any `insert` into `main.*`, and before the first
  `select` on a table not yet seen in the session, one query on
  `information_schema.columns` (snake_case, users live in `main`, not `auth`;
  guessed `plan_id` / `message` failed, 68513abd).
  Backfill scripts go in the scratchpad and run with `-v ON_ERROR_STOP=1`.
- **`prisma migrate reset` on `main` trips on other branches' schemas.** After
  the `pg_stat_activity` check: `drop schema if exists pgboss, ory_import,
  ory_revert, partman cascade`, then reset. `already exists` means a leftover
  schema, not a bad migration (2026-10-14, 2 failed resets).
- **`PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION` is Greg's own words.** Ask
  for the go-ahead naming the target ("`localhost:5432/main`, lokalnie, nic nie
  wychodzi") and pass his reply verbatim. Never invent it; YOLO is not consent
  to a destructive reset.

## Shared lab environments (`lab*`) are the same story, remotely

Before `gh workflow run deploy-env.yml` / `redeploy-env.yml` against a shared
lab, check who holds it: `gh run list --workflow deploy-env.yml --status
in_progress`. An active PR deploy → stop and say whose it is (a blind dispatch
failed twice on 2026-10-02). After a failure read `gh run view <id>
--log-failed` before dispatching again, never in a loop.

## Screenshots for a PR from a local stack

~25 calls on traps that are all known up front (9adba92d):

- `docker` looks for colima's socket in `~/.config/colima`; it lives in
  `~/.colima`: `DOCKER_HOST=unix://$HOME/.colima/default/docker.sock`.
- Size colima before `pnpm start` (12 GiB, 6 CPU did it).
- No downloaded Playwright browser or ffmpeg: a one-off spec uses
  `channel: 'chrome'`, video and trace off, lives in the scratchpad and is
  deleted after.
- A new org gets a trial plan and 403 "Missing required entitlement" on paid
  features: use the seeded `default` org and its owner.
- Handing Greg a local login: the email in a fenced code block (a list indent
  adds a leading space the form doesn't trim), the password only on the
  clipboard (`printf %s … | pbcopy`, cleared after), never in chat. Check the
  account once with a direct API call first.
- **Where PR screenshots go:** `git ls-remote origin | rg -i screenshots` shows
  the convention, a PNG-only `<branch>-screenshots` branch. Push it as an orphan
  commit without a checkout: `git hash-object -w` → `git mktree` → `c=$(git
  commit-tree …)`, `[ -n "$c" ]`, then `git push origin "${c}:refs/heads/<branch>-screenshots"`
  (braced: `$c:r…` is a zsh modifier). The PR body links the raw files (a120142c).

## A worktree `work` did not seed is missing seven things

`work` seeds every worktree it opens: `place-work-skills <path>` copies the
work-scoped skills (`g-pr`, `g-pr-review`, `g-github-issue`, …) into
`<path>/.claude/skills/`, and the seed step clones the gitignored `.env*` and
`*.env.json` files, `node_modules` and `.husky/_` from the parent checkout. A
worktree made with plain git has none. On 2026-09-23 `/g-pr` was not in the
picker (the team's `pr` skill ran instead) and `pnpm start` died on a missing
`local/.env`. A missing `.husky/_` made every commit fail on
`.husky/_/husky.sh: No such file or directory`, and earlier commits skipped
lint-staged, which surfaced later as a red `oxfmt --check` in CI. The fix is
`pnpm install --config.confirmModulesPurge=false` in the worktree (~40 s, no
`./install.sh`), never `--no-verify`. `guard` denies a bare `pnpm install` (no
TTY for pnpm's purge prompt) and `CI=true pnpm install`.

A fourth gap: **built workspace packages.** vitest in a fresh worktree failing
with `ERR_MODULE_NOT_FOUND` / `Cannot find package '@<org>/<pkg>'` means the
workspace packages it imports were never built there. Run the `nx` target of
the package under test once (`pnpm exec nx run <project>:ts:check`, 3–6 min,
in the background) before the first test run. `pnpm install` does not fix it
(2026-09-30). Component tests in `apps/ui` need four of them at once: build
them in one `pnpm exec nx run-many --target=build --projects=<a>,<b>,…`, not
one per failed run (3 rounds, 2cb11215). `Failed to resolve import
"./generated-async"` is the async-API SDK package unbuilt. In `apps/api`,
`Cannot find package '@<org>/shared'` before a `*.db.spec.ts` is the same gap:
build that package in the background first; a spec that never ran is "nie
uruchomiony", not green (fa996d11). A stacked worktree (`--base
origin/<feature>`) and `apps/ui` (plus `shared`) have the same gap: right after
`workctl`, in the background, `pnpm exec nx run <api>:deps:build` (0c6b2490).

A fifth gap: **the e2e config `playwright.env.json`** (gitignored, next to the
e2e suite): `Failed to find .rc file at …/playwright.env.json`. `workctl`
clones `*.env.json` since 2026-10-06; in an older worktree `cp -c <main
checkout>/<same path> <worktree>/<same path>`, without printing it.

A sixth gap: **`local/current.profile.json`.** Without it `pnpm start` doesn't
pass the Support allowlist to the API. `workctl` clones it since 2026-10-12;
in an older tree `test -f local/current.profile.json || pnpm run profile
default` before the first `pnpm start`.

**Check the worktree at the start of the session, not when a skill misfires.**
In any `~/Code/tree/wt-*` or `~/.local/share/tuios/worktrees/*/*` path (tuios's
own worktrees are unseeded too; so were herdr's `~/.herdr/worktrees/*/worktree-*`, 03b98f19): `test -d node_modules && test -d
.husky/_` before the first commit, else `pnpm install` as above;
`.claude/skills/g-pr` missing → run
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

A seventh gap: **`.env` keys older than `.env.example`.** The files exist, so
`copy-env-from-main.sh` skips them, but the branch added keys. Symptom: an app
online in pm2 that answers 502, or `X: Required` in `pnpm pm2 logs <app>`.
Diff key names only, never values:
`comm -23 <(rg -o '^([A-Z0-9_]+)=' -r '$1' .env.example | sort -u) <(rg -o
'^([A-Z0-9_]+)=' -r '$1' .env | sort -u)`. Append the missing lines from
`.env.example`, `pnpm pm2 restart <app>`, and check this before suspecting code.

The fourth gap has a stale variant: a built `lib` lacking a new export fails
on the missing symbol, not `ERR_MODULE_NOT_FOUND`. Before a local e2e run build
what CI builds (the e2e profile's `nx` target, ~25 min, background), not just
the package under test.
