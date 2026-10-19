---
description: Production database through the bastion tunnel and jamsql — confirm the region behind the tunnel, read the schema before querying, prove the row exists on that connection before any write
alwaysApply: true
---

# Prod Database via the Tunnel — Region First, Schema Second

Prod Postgres is reached through a bastion tunnel on a local port and queried
with the jamsql MCP, one connection per region (US, EU). Two sessions
(2026-10-15, 10-16) hit the same traps: a tunnel switched region mid-session
because another process reconnected it, an `UPDATE` aimed at the US connection
for a row that lives in EU (Greg: "zła baza … przełączyć na bazę us?"), and
nine query errors from guessed table and column names.

## Before the first query

1. **Which region is the tunnel on?** `ps -axo command | rg '[b]asti.*connect'`
   and `lsof -nP -iTCP:<port>`. Match the jamsql connection to that region.
   Tunnel changed since the last query → `connections_connect` before
   `query_execute`.
2. **Name the target in one line:** "prod EU, read-only, nic nie zapisuję".
3. **Read the schema, don't guess it.** First query on an unknown table →
   `information_schema.columns`. SSO tables live in the `auth` schema; a
   config column may be `json` or `text`, cast explicitly.

## Before a write

- **Prove the row is on this connection.** A read-only `select … where id =
  '<id>'` on the same connection must return exactly one row. Zero rows means
  the wrong region: check the other one, and don't ask for write approval yet.
- **The popup names connection and region** (US/EU), not just the database name.
- **`query_execute` wraps the query in a cursor**, so a `WITH … UPDATE` fails
  with `DECLARE CURSOR must not contain data-modifying statements`. A write is a
  plain `UPDATE` in its own call.

## When it breaks

- `Failed to connect` → `nc -z localhost <port>`; the tunnel is down. Don't
  retry the connect.
- The tunnel was switched under you by someone else → ask Greg, don't switch it
  back yourself.
