---
paths: "apps/**, packages/**, local/**, e2e/**, platform/**, nx.json, pnpm-workspace.yaml, docker-compose.yml"
---

# Work monorepo — local stack, database, worktree seed

The always-on part is `shared-local-docker.md`. Read-only queries need no check from it.

## Reading and seeding the local database

- **The Mac has no `psql`.** Always `docker exec "$co-postgres-1" psql -U myuser -d <db> -At -c "…"`, `create database` for a spec included.
- **Prisma's table is `prisma._prisma_migrations`**: `select migration_name, finished_at from prisma._prisma_migrations order by finished_at desc limit 20`.
- **A Node check needing `pg` runs from `apps/api`** (`packages/database` can't resolve it). Runner scripts for DB specs go in the scratchpad.
- **Postgres stopped by `pnpm stop` comes back with `docker compose -p <co> up -d --wait postgres`**, not `docker start`. Before `pnpm start`, note `docker ps --format '{{.Names}}'` to know what to restore.
- **The first `pnpm start` in a fresh worktree builds images ~25 min**: background, `timeout 3000` (or none), `Monitor` on the log. `exit=124` from a shorter timeout means "read the log", not "retry".
- **DB specs use their own database, never `main`** (`db_specs` or a new one). Build the URL inline in single quotes, never in a file: `pw=$(docker exec "$co-postgres-1" printenv POSTGRES_PASSWORD)`, then `VAR='postgresql://myuser:'"$pw"'@localhost:5432/db_specs' pnpm exec vitest …`. Don't grep `.env` for it.
- **A migration test runs on a clone of `main`**: `docker exec "$co-postgres-1" sh -c 'createdb -U myuser <scratch> && pg_dump -U myuser -d main --no-owner | psql -U myuser -d <scratch> -q -v ON_ERROR_STOP=1'`. Say "lokalnie, kopia `main` do `<scratch>`", drop it after; `already exists` = another branch's leftover schema. The clone's URL ends `?schema=prisma&sslmode=disable` (single quotes); `P3005` means that's missing. Before `better-auth` specs `delete from auth.jwks` on the clone, never `main` (symptom: `Unexpected end of JSON input` on `/token`).
- **A fresh database needs the Ory schemas before Prisma**: `create schema kratos; create schema hydra`, Ory migrations from the `oryd/hydra` image (DSN with `search_path=hydra`, same for kratos), then `prisma migrate deploy`. `P3009` there = schemas missing. Drop your own database when done.
- **`prisma migrate reset` on `main` trips on other branches' schemas.** After the `pg_stat_activity` check: `drop schema if exists pgboss, ory_import, ory_revert, partman cascade`, then reset.
- **`PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION` is Greg's own words.** Ask naming the target ("`localhost:5432/main`, lokalnie, nic nie wychodzi"), pass his reply verbatim. Never invent it; YOLO is not consent to a destructive reset.
- **Empty UI after `db:seed` → Greg's membership first**: the seed only makes memberships for the seed user; Greg needs an `OWNER` row in the `default` org. Before any `insert` into `main.*` and the first `select` on an unseen table, one query on `information_schema.columns` (snake_case; users live in `main`, not `auth`). Backfills: scratchpad, `-v ON_ERROR_STOP=1`.
- **colima has `mounts: []`**: `-v <host dir>:/x` sees an empty path. Use `docker cp`, a volume, or bake into the image.
- **Handing the stack to Greg:** last `pnpm pm2 restart api auth-server temporal-worker`, `prisma._prisma_migrations` rows vs the `prisma/migrations` dirs, `curl` on `/` (307) and the API. No `nx` on shared libraries during his test.

## Shared lab environments (`lab*`)

Before `gh workflow run deploy-env.yml` / `redeploy-env.yml`: `gh run list --workflow deploy-env.yml --status in_progress`. An active PR deploy → stop and say whose. After a failure read `gh run view <id> --log-failed` before dispatching again, never in a loop.

## Screenshots for a PR from a local stack

- "Before" shot first, on clean `origin/main`. After `lde restart ui` wait for a 200 in one `timeout` loop.
- `DOCKER_HOST=unix://$HOME/.colima/default/docker.sock` (docker looks in `~/.config/colima`). Size colima before `pnpm start` (12 GiB, 6 CPU).
- No downloaded Playwright browser or ffmpeg: a one-off spec uses `channel: 'chrome'`, video and trace off, lives in the scratchpad, deleted after.
- A new org gets a trial plan (403 "Missing required entitlement"): use the seeded `default` org and its owner.
- Local login for Greg: email in a fenced code block (a list indent adds a space the form doesn't trim), password only on the clipboard (`printf %s … | pbcopy`, cleared after). Check the account with a direct API call first.
- **Where they go:** `git ls-remote origin | rg -i screenshots` shows the convention, a PNG-only `<branch>-screenshots` branch. Push it as an orphan commit without a checkout: `git hash-object -w` → `git mktree` → `c=$(git commit-tree …)`, `[ -n "$c" ]`, `git push origin "${c}:refs/heads/<branch>-screenshots"`. The PR body links the raw files.

## A worktree `work` did not seed

`work`/`workctl` seeds every worktree: `place-work-skills <path>` copies the work skills (`g-pr`, `g-pr-review`, …) into `<path>/.claude/skills/`, and it clones the gitignored `.env*`, `*.env.json`, `local/current.profile.json`, `node_modules` and `.husky/_` from the parent. Plain-git and tuios worktrees (`~/.local/share/tuios/worktrees/*/*`) get none.

**At session start in any `~/Code/tree/wt-*` or tuios worktree, not when a skill misfires:**

1. `test -d node_modules && test -d .husky/_` before the first commit, else `pnpm install --config.confirmModulesPurge=false` (~40 s; guard denies the other forms). A missing `.husky/_` fails every commit on `husky.sh: No such file`; never `--no-verify`.
2. `g-pr` missing from the skill list (the team's `pr` would run instead) or a needed `.env` missing → `place-work-skills <worktree>` (no-op outside work repos), then `bash <worktree>/.claude/skills/worktree-dev/scripts/copy-env-from-main.sh` (copies only missing `.env` files, never prints them). Never fall back to the team's same-purpose skill. `/g-pr*` still "Unknown command" → `/exit`, `claude --continue`.
3. **Built workspace packages.** `ERR_MODULE_NOT_FOUND` / `Cannot find package '@<org>/<pkg>'` in vitest (also before a `*.db.spec.ts` in `apps/api`), or `Failed to resolve import "./generated-async"` (async-API SDK) → build that package's nx target in the background (`pnpm exec nx run <project>:ts:check`, 3–6 min); `pnpm install` doesn't fix it. `apps/ui` component tests need several: one `pnpm exec nx run-many --target=build --projects=<a>,<b>,…`. Stacked worktrees and `apps/ui`: right after `workctl`, `pnpm exec nx run <api>:deps:build` in the background. A spec that never ran is "nie uruchomiony", not green. Stale variant: a built `lib` lacking a new export fails on the symbol; before a local e2e run build what CI builds (the e2e profile's nx target, ~25 min, background).
4. **`playwright.env.json`** missing (`Failed to find .rc file`) in an older worktree → `cp -c <main checkout>/<path> <worktree>/<path>`, without printing it.
5. **`local/current.profile.json`** missing → `pnpm run profile default` before the first `pnpm start` (else the API lacks the Support allowlist).
6. **`.env` keys older than `.env.example`** (files exist so the copy skips them): pm2 app online but 502, or `X: Required` in `pnpm pm2 logs <app>`. Diff names only: `comm -23 <(rg -o '^([A-Z0-9_]+)=' -r '$1' .env.example | sort -u) <(rg -o '^([A-Z0-9_]+)=' -r '$1' .env | sort -u)`, append the missing lines from `.env.example`, `pnpm pm2 restart <app>`. Check this before suspecting code.
