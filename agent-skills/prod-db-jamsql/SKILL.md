---
name: prod-db-jamsql
description: Production Postgres through the bastion tunnel and the jamsql MCP: confirm the tunnel's region (US/EU) first, read the schema instead of guessing, prove the row is on this connection before any write, open writes Greg runs himself in a Jam SQL tab. Load BEFORE any mcp__jamsql__* call, a bastion tunnel, or a query or UPDATE against prod / prodeu.
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

## Before the tunnel: can jamsql connect at all?

The tunnel closes when idle, so it is opened last (2264f7b9: three rounds,
zero queries).

1. `connections_list` and `ui_list_tabs` first. `AI connection control is
   disabled` or `No browser window available` is Greg's step: Settings → AI
   Integrations → allow AI to connect with saved connections, and a Jam SQL
   window open. Ask once, one numbered step.
2. After his "kk": tunnel, `connections_connect`, read-only query, in one go.
3. Still failing with the tunnel up → `nc -z localhost <port>` once, then say
   what blocks on the Jam SQL side. No `connections_connect` loop.

## Before a write

- **Prove the row is on this connection.** A read-only `select … where id =
  '<id>'` on the same connection must return exactly one row. Zero rows means
  the wrong region: check the other one, and don't ask for write approval yet.
- **The popup names connection and region** (US/EU), not just the database name.
- **`query_execute` wraps the query in a cursor**, so a `WITH … UPDATE` fails
  with `DECLARE CURSOR must not contain data-modifying statements`. A write is a
  plain `UPDATE` in its own call.

## A write Greg runs himself: open it in a tab

Greg picked "ty odpalasz UPDATE" and got two SQL blocks to copy: "a nie możesz
mi tego dodać?" (df44b632). Open it with `ui_open_tab` (`initialSql`, the
region's `connectionId`, "one statement at a time" as a SQL comment), never
`ui_execute_query`. In chat one line: region, tab title, expected row count.
After his "poszło", a read-only check on the same connection.

## When it breaks

- `Failed to connect` → `nc -z localhost <port>`; the tunnel is down. Don't
  retry the connect.
- The tunnel was switched under you by someone else → ask Greg, don't switch it
  back yourself.
