---
description: Local Docker and Postgres are shared with Greg's other sessions — check that nothing else is using them before any drop, restart, recreate or pkill
alwaysApply: true
---

# Local Docker Is Shared — Check Before You Disrupt It

The local Docker stack (the `<co>-*` containers, `<co>-postgres-1`, the `main`
database; `<co>` is `$WORK_COMPANY` lowercased) is not yours alone. Other herdr agents and Greg's own long jobs
use it at the same time — on 2026-09-23 one of them was dumping production data
through it for two hours. A single agent session then ran `drop database main
with (force)`, a `pnpm start` that restarted and rebuilt containers, and a broad
`pkill -f 'docker compose -p <co>'` — one of them killed that job, and two
hours of dump were thrown away.

## Before a disruptive step

Disruptive means: `DROP DATABASE` (above all `WITH (force)`, which kills every
connection), `pg_terminate_backend`, `docker compose up/down/restart`,
`pnpm start` / `pnpm stop` in the work monorepo, `docker rm/restart`, image
rebuilds, and any `pkill`/`killall`.

1. **Look for other users first:**

   ```bash
   co=$(printf %s "$WORK_COMPANY" | tr '[:upper:]' '[:lower:]')
   docker exec "$co-postgres-1" psql -U myuser -d postgres -At -c \
     "select pid, datname, application_name, state, now()-xact_start, left(query,80)
      from pg_stat_activity where pid <> pg_backend_pid() and datname is not null"
   ps -axo pid,etime,command | rg -i 'pg_dump|pg_restore|psql|docker (exec|run|compose)' | rg -v rg
   ```

   Also check other agents with `ListAgents` / the herdr sidebar.
2. **Anything long-running you did not start → stop and ask Greg.** Name what
   you found (pid, command, how long it has run). Do not decide it is stale.
3. **Nothing found → say so in one line, then proceed.**

## Rules

- **Never `pkill -f` a broad pattern.** Stop only what you started: its task id
  (`TaskStop`) or the pid you recorded. A pattern like `docker compose -p
  <co>` matches every session's processes.
- **Never `DROP DATABASE … WITH (force)` without the check above.** Plain
  `DROP DATABASE` failing on "database is being accessed" is the signal to look,
  not an obstacle to force through.
- **A full `pnpm start` is heavy and touches every container.** Say so before
  starting it, run it once, and on failure read the log instead of retrying in
  a loop — each retry rebuilds and restarts again.
- **A stopped container whose network is gone needs a recreate.** `docker
  start <c>` → `network … not found`, and `docker compose up -d` alone keeps
  pointing at the old network (3 failed tries, 2026-09-30). After the check
  above: `docker inspect <c> --format '{{range .Mounts}}{{.Type}} {{.Name}}{{"\n"}}{{end}}'`
  — data on a named volume means a recreate is safe — then `docker compose -p
  <project label> up -d --no-deps --force-recreate <service>`.
- **`docker build` failing on `Lockfile failed supply-chain policy check` is
  not flaky.** Two rebuilds of ~17 min each hit the same error (2026-10-04).
  Don't rebuild: read the pnpm policy line (which package, which rule), report
  it with the recovery move (pin or bump that dependency, or a build context
  that does not match the lockfile), and retry only after the lockfile
  changed. Say the ~17 min cost before any rebuild.

## Reading and seeding the local database

Read-only queries need no check above. Three lookups each cost two or three
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
in_progress`. An active PR deploy → stop and say whose it is. A blind dispatch
failed twice with "has an active PR deploy" on 2026-10-02, and each one costs a
CI run and can disturb someone else's deploy. After a failure, read
`gh run view <id> --log-failed` before dispatching again, never in a loop.

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
  put a leading space in it and the form does not trim), the password only on
  the clipboard (`printf %s … | pbcopy`, cleared after), never in chat. Check
  the account once with a direct API call first.
