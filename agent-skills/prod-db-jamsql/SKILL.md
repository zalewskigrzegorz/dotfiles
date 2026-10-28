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

1. **Which region is the tunnel on?** Print only pid, region and host:
   `ps -axo pid,etime,command | rg -o '[s]ession-manager-plugin.*?(eu-central-1|us-east-1) StartSession.*?"host":\["[^"]+"\]' | rg -o '^\S+|"host":\["[^"]+"\]'`,
   plus `lsof -nP -iTCP:<port>`. **Never print the raw `ps` line of
   `session-manager-plugin`**: it carries the SSM `SessionId` and a live
   stream token (`wss://ssmmessages…`), which then sit in the transcript
   (5291ecd3). Match the jamsql connection to that region. Tunnel changed
   since the last query → Greg reconnects in Jam SQL; after his "kk", one
   `select inet_server_addr()` on the region's `connectionId`, never
   `connections_connect`.
2. **Name the target in one line:** "prod EU, read-only, nic nie zapisuję".
3. **Read the schema, don't guess it.** First query on an unknown table →
   `information_schema.columns`. SSO tables live in the `auth` schema; a
   config column may be `json` or `text`, cast explicitly.

## Before the tunnel: can jamsql connect at all?

The tunnel closes when idle, so it is opened last (2264f7b9: three rounds,
zero queries).

1. `connections_list` and `ui_list_tabs` first. `AI connection control is
   disabled` is the intended state: **Greg connects himself** ("nie ja bede sam
   przelaczal tak jest bezpieczniej", 02c6f9fd). Don't ask him to allow AI
   connect, and never call `connections_connect` or `query_get_results`
   (`Share results is disabled` too). Ask once for the connection open in a
   Jam SQL window. `ECONNREFUSED` from `ToolSearch +jamsql` means the app is
   closed: he opens it, then `/mcp` → jamsql → Reconnect.
2. After his "kk": tunnel region via `ps`/`lsof` and one `select
   inet_server_addr()` on his `connectionId`, then read-only queries on it.
   The result of a step he ran in a tab is read back with `query_execute` on
   the same connection.
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

## A write the agent runs, Greg approves in Jam SQL

Under "write with approval" each `UPDATE` raises an approval window. Four sent
in parallel raised four at once and three came back "Write query was denied
by the user"; 2 of 5 certificates landed (a656141a).

- Before the first write, one line: "zaraz N okien zatwierdzenia, po jednym,
  region X, tabela Y".
- One write `query_execute` per turn, never in parallel. Wait for its result.
- "Write query was denied" means not run. After the series, a read-only check
  of every row on the same connection, never an assumption.

## A missing grant: live first, then the migration

Worked on US and EU (ebcbd85f):

1. Prove the region, then read-only: `has_table_privilege('<role>', '<schema.table>', 'SELECT')` is false.
2. One Jam SQL tab per region, region in the title: an idempotent `GRANT` looping over the roles that need it.
3. After his "poszło": `SELECT` true and `INSERT` false on the same `connectionId`.
4. Then the same SQL as a plain migration in the repo: a no-op on prod, the grant on stage and labs at deploy.

## Backups and snapshots

Read-only, first line "read-only, nic nie odtwarzam" (a120142c, 5 calls):
`aws --profile <prod-profile> --region <r> rds describe-db-snapshots
--db-instance-identifier <id> --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0]'`.
Instances, not clusters; US is `us-east-1`, EU `eu-central-1`; automated
daily snapshots land around 07:08 UTC. Loop regions with a function
(`snap() { aws … --region "$1" … "$2"; }`), never `set -- $p` in zsh. A
restore is a separate task with its own go-ahead.

## When it breaks

- `Failed to connect` → `nc -z localhost <port>`; the tunnel is down. Don't
  retry the connect.
- The tunnel was switched under you by someone else → ask Greg, don't switch it
  back yourself.
