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
