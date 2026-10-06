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

## Shared lab environments (`lab*`) are the same story, remotely

Before `gh workflow run deploy-env.yml` / `redeploy-env.yml` against a shared
lab, check who holds it: `gh run list --workflow deploy-env.yml --status
in_progress`. An active PR deploy → stop and say whose it is. A blind dispatch
failed twice with "has an active PR deploy" on 2026-10-02, and each one costs a
CI run and can disturb someone else's deploy. After a failure, read
`gh run view <id> --log-failed` before dispatching again, never in a loop.
