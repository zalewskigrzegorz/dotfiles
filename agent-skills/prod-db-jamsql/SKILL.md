---
name: prod-db-jamsql
description: Production Postgres through the bastion tunnel and the jamsql MCP: confirm the tunnel's region (US/EU) first, read the schema instead of guessing, prove the row is on this connection before any write, open writes Greg runs himself in a Jam SQL tab. Load BEFORE any mcp__jamsql__* call, a bastion tunnel, or a query or UPDATE against prod / prodeu.
---

# Prod database via the tunnel — region first, schema second

Bastion tunnel on a local port, jamsql MCP, one connection per region. Past
traps: a tunnel switched region mid-session (another process reconnected it),
an `UPDATE` aimed at US for an EU row, nine errors from guessed names.

## Can jamsql connect? (before the tunnel, which closes when idle)

1. `connections_list` and `ui_list_tabs` first. `AI connection control is
   disabled` is intended: **Greg connects himself** ("tak jest bezpieczniej").
   Never ask him to allow AI connect, never `connections_connect` or
   `query_get_results` (`Share results is disabled` too). Ask once for the
   connection open in a Jam SQL window. `ECONNREFUSED` from `ToolSearch
   +jamsql` = app closed: he opens it, then `/mcp` → jamsql → Reconnect.
2. After his "kk": region check below, one `select inet_server_addr()` on his
   `connectionId`, then read-only queries there. A step he ran in a tab is
   read back with `query_execute` on the same connection.
3. Failing with the tunnel up → `nc -z localhost <port>` once, say what blocks
   on the Jam SQL side. No connect loop.

## Before the first query

1. **Which region?** Only pid, region, host:
   `ps -axo pid,etime,command | rg -o '[s]ession-manager-plugin.*?(eu-central-1|us-east-1) StartSession.*?"host":\["[^"]+"\]' | rg -o '^\S+|"host":\["[^"]+"\]'`
   plus `lsof -nP -iTCP:<port>`. **Never print the raw `session-manager-plugin`
   line**: it carries the SSM `SessionId` and a live stream token. Match the
   jamsql connection to the region. Tunnel changed → Greg reconnects in Jam
   SQL; after "kk" one `select inet_server_addr()`.
2. **Name the target**: "prod EU, read-only, nic nie zapisuję".
3. **Read the schema**: unknown table → `information_schema.columns` first.
   SSO tables live in `auth`; a config column may be `json` or `text`, cast
   explicitly. `main.subscriptions.details` is jsonb and may be SQL NULL or
   JSON `null`: `where jsonb_typeof(details)='object'` before
   `jsonb_object_keys` / `jsonb_each_text` / `jsonb_array_elements`. `items`
   is an array (several per subscription): count `count(distinct s.id)` (70
   rows were 63 subscriptions). A vendor order id is `"orderId"` in quotes.

## Before a write

- **Prove the row is here**: a read-only `select … where id = '<id>'` on the
  same connection returns exactly one row. Zero → wrong region, check the
  other one, no approval request yet.
- The popup names connection and region, not just the database.
- `query_execute` wraps queries in a cursor: `WITH … UPDATE` fails (`DECLARE
  CURSOR must not contain data-modifying statements`). A write is a plain
  `UPDATE` in its own call.

## A write Greg runs: open it in a tab

`ui_open_tab` with `initialSql`, the region's `connectionId`, and "one
statement at a time" as a SQL comment; never `ui_execute_query`, never SQL
blocks to copy. In chat one line: region, tab title, expected row count. After
"poszło", a read-only check on the same connection.

## A write you run, Greg approves in Jam SQL

Each `UPDATE` raises an approval window (four in parallel → three denied).
First one line "zaraz N okien zatwierdzenia, po jednym, region X, tabela Y";
one write per turn, wait for its result. "Write query was denied" = not run.
Afterwards a read-only check of every row, never an assumption.

## A missing grant: live first, then the migration

1. Prove the region; `has_table_privilege('<role>', '<schema.table>', 'SELECT')` is false.
2. One Jam SQL tab per region (region in the title): an idempotent `GRANT`
   looping over the roles.
3. After "poszło": `SELECT` true, `INSERT` false on the same `connectionId`.
4. The same SQL as a plain repo migration (no-op on prod, grant on stage/labs).

## Backups and snapshots

Read-only, first line "read-only, nic nie odtwarzam": `aws --profile
<prod-profile> --region <r> rds describe-db-snapshots --db-instance-identifier
<id> --query 'reverse(sort_by(DBSnapshots,&SnapshotCreateTime))[0]'`.
Instances, not clusters; US `us-east-1`, EU `eu-central-1`; automated daily
snapshots ~07:08 UTC. Loop regions with a function (`snap() { aws … --region
"$1" … "$2"; }`), never `set -- $p` in zsh. A restore is its own task and
go-ahead.

## A read compared later

Feeds an incident, restore or backfill → save the full id list in
`~/Code/personal/bazgroly/<repo>/notes/YYYY-MM-DD-<topic>.md` (date, region,
query, ids only, no customer data); say the path.

## When it breaks

`Failed to connect` → `nc -z localhost <port>`, tunnel down, no retry. The
tunnel switched under you → ask Greg, don't switch it back.
