---
description: Local Docker and Postgres are shared with Greg's other sessions — check that nothing else is using them before any drop, restart, recreate or pkill
alwaysApply: true
---

# Local Docker Is Shared: Check Before You Disrupt It

The local stack (`<co>-*` containers, `<co>-postgres-1`, database `main`; `<co>` = `$WORK_COMPANY` lowercased) is shared with other tuios agents and Greg's long jobs: a session's `drop database main with (force)` once killed a two-hour production dump.

**Disruptive** = `DROP DATABASE` (above all `WITH (force)`), `pg_terminate_backend`, `docker compose up/down/restart`, `pnpm start`/`pnpm stop` in the work monorepo, `docker rm/restart`, image rebuilds, any `pkill`/`killall`. Before one:

1. **Look for other users**:
   ```bash
   co=$(printf %s "$WORK_COMPANY" | tr '[:upper:]' '[:lower:]')
   docker exec "$co-postgres-1" psql -U myuser -d postgres -At -c \
     "select pid, datname, application_name, state, now()-xact_start, left(query,80)
      from pg_stat_activity where pid <> pg_backend_pid() and datname is not null"
   ps -axo pid,etime,command | rg -i 'pg_dump|pg_restore|psql|docker (exec|run|compose)' | rg -v rg
   ```
   plus other agents (`ListAgents` / the tuios sidebar).
2. **Anything long-running you didn't start → stop and ask Greg**, naming pid, command and runtime; never decide it is stale.
3. **Nothing found → one line, proceed.**

- **Never `pkill -f` a broad pattern** (`docker compose -p <co>` matches every session): stop only your task id (`TaskStop`) or recorded pid.
- **Plain `DROP DATABASE` failing on "being accessed"** is the signal to look, not an obstacle to force.
- **A full `pnpm start` is heavy** and touches every container: say so first, run once, on failure read the log instead of retrying.
- **A stopped container whose network is gone** (`docker start` → `network … not found`; `compose up -d` alone keeps the old network): after the check, `docker inspect <c> --format '{{range .Mounts}}{{.Type}} {{.Name}}{{"\n"}}{{end}}'` (data on a named volume = safe), then `docker compose -p <project label> up -d --no-deps --force-recreate <service>`.
- **`docker build` failing on `Lockfile failed supply-chain policy check` is not flaky**: don't rebuild (~17 min each); report the package and rule from the policy line with the recovery move (pin or bump), retry only after the lockfile changed. Say the ~17 min cost before any rebuild.

Reading and seeding the local DB, shared `lab*` deploys, PR screenshots from a local stack: `~/.claude/rules/work-local-stack.md` (`Read` it before a DB step if not in context).
