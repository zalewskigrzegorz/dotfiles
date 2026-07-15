# grafana-query.nu — query the work Grafana's datasources (ClickHouse / Prometheus)
# from the terminal WITHOUT docker and WITHOUT a connected MCP.
#
# Why: the datasources are NOT exposed directly — they live behind Grafana's
# proxy. So a native clickhouse-client / promtool can't reach them. These
# wrappers go through Grafana's HTTP API with a single Grafana token:
#   - ClickHouse → POST /api/ds/query  (rawSql, grafana-clickhouse-datasource)
#   - Prometheus → GET  /api/datasources/proxy/uid/<uid>/api/v1/query[_range]
#
# There is NO Loki datasource in this Grafana (checked 2026-07-15). Logs live in
# ClickHouse `default.otel_traces` (use ch-query) and CloudWatch (use aws cli).
#
# Token resolution (first hit wins), so you only ever update ONE place — 1Password:
#   1. $env.GRAFANA_SERVICE_ACCOUNT_TOKEN or $env.GRAFANA_TOKEN
#   2. `op read op://Dotfiles/GRAFANA_SERVICE_ACCOUNT_TOKEN/password`
# When the token rotates (Grafana does it org-side) and you get 401, just paste a
# fresh SA token into that 1Password item — every wrapper picks it up next call.
#
#   ch-query   'SELECT 1'                       # ClickHouse Prod by default
#   ch-query   'SELECT ...' --uid <uid> --start now-30d
#   prom-query 'up'                             # instant, Prometheus prod by default
#   prom-query 'rate(http_requests_total[5m])' --range --start now-1h --step 60
#   prom-query 'up' --uid <uid>                 # another Prometheus (11 exist; see below)
#   grafana-datasources                         # list uid/type/name (needs live token)

const OP_TOKEN_REF = "op://Dotfiles/GRAFANA_SERVICE_ACCOUNT_TOKEN/password"
# Grafana base URL — kept out of this public repo. Set $env.GRAFANA_URL (private.nu
# does), or store it on the token's 1Password item so it resolves cross-machine.
const OP_URL_REF = "op://Dotfiles/GRAFANA_SERVICE_ACCOUNT_TOKEN/url"
# ClickHouse Prod (org/customer data). See grafana-mcp-wtf skill for stage/temp UIDs.
const CH_UID_DEFAULT = "ae1qrvykddz40a"
const CH_DS_TYPE = "grafana-clickhouse-datasource"
# Prometheus prod (11 Prometheus datasources exist — `grafana-datasources` lists all;
# override per call with --uid). Notables: prod 6R6YNqu4z, prod-eu MrgKdanSk,
# dev 5lLidyU4z, stage bdnconxrypzwgc, app ee54gr338x5vkc, projects ee54h0w5c9hc0c.
const PROM_UID_DEFAULT = "6R6YNqu4z"

def _grafana-url []: nothing -> string {
    let e = ($env.GRAFANA_URL? | default "")
    let u = (if ($e | is-not-empty) {
        $e
    } else if (which op | is-not-empty) {
        let r = (do { ^op read $OP_URL_REF } | complete)
        if $r.exit_code == 0 { ($r.stdout | str trim) } else { "" }
    } else { "" })
    if ($u | is-empty) {
        error make {msg: $"no Grafana URL — set $env.GRAFANA_URL or store it at ($OP_URL_REF)"}
    }
    $u | str trim --right --char '/'
}

# env first (fast), else pull from 1Password on demand.
def _grafana-token []: nothing -> string {
    let e = ($env.GRAFANA_SERVICE_ACCOUNT_TOKEN? | default ($env.GRAFANA_TOKEN? | default ""))
    if ($e | is-not-empty) { return $e }
    if (which op | is-empty) {
        error make {msg: "no GRAFANA token in env and `op` CLI not found — set GRAFANA_SERVICE_ACCOUNT_TOKEN or install 1Password CLI"}
    }
    let r = (do { ^op read $OP_TOKEN_REF } | complete)
    if $r.exit_code != 0 {
        error make {msg: $"could not read token from 1Password (($OP_TOKEN_REF)): ($r.stderr | str trim)"}
    }
    ($r.stdout | str trim)
}

# GET through Grafana, return parsed JSON. Surfaces 401 clearly (dead token).
def _grafana-get [path: string]: nothing -> any {
    let url = (_grafana-url)
    let tok = (_grafana-token)
    let r = (do { ^curl -s -w "\n%{http_code}" -H $"Authorization: Bearer ($tok)" $"($url)($path)" } | complete)
    let lines = ($r.stdout | lines)
    let code = ($lines | last)
    let body = ($lines | drop | str join "\n")
    if $code == "401" {
        error make {msg: "Grafana 401 — token is expired/rotated. Generate a fresh SA token and paste it into 1Password (op://Dotfiles/GRAFANA_SERVICE_ACCOUNT_TOKEN/password)."}
    }
    if $code != "200" { error make {msg: $"Grafana HTTP ($code): ($body | str substring 0..300)"} }
    ($body | from json)
}

# POST JSON through Grafana, return parsed JSON.
def _grafana-post [path: string, payload: any]: nothing -> any {
    let url = (_grafana-url)
    let tok = (_grafana-token)
    let r = (do {
        $payload | to json -r | ^curl -s -w "\n%{http_code}" -X POST $"($url)($path)" -H $"Authorization: Bearer ($tok)" -H "Content-Type: application/json" --data-binary "@-"
    } | complete)
    let lines = ($r.stdout | lines)
    let code = ($lines | last)
    let body = ($lines | drop | str join "\n")
    if $code == "401" {
        error make {msg: "Grafana 401 — token is expired/rotated. Paste a fresh SA token into 1Password (op://Dotfiles/GRAFANA_SERVICE_ACCOUNT_TOKEN/password)."}
    }
    if $code != "200" { error make {msg: $"Grafana HTTP ($code): ($body | str substring 0..300)"} }
    ($body | from json)
}

# List datasources — uid / type / name. Handy for grabbing Prometheus/Loki UIDs.
export def grafana-datasources []: nothing -> table {
    _grafana-get "/api/datasources" | select uid type name | sort-by type name
}

# ClickHouse SQL via /api/ds/query. Defaults to ClickHouse Prod + a 90d window.
# Returns the raw frames JSON; pipe through `get results.A.frames` etc. to shape.
export def ch-query [
    sql: string
    --uid: string = ""            # datasource UID (default: ClickHouse Prod)
    --start: string = "now-90d"   # range from
    --end: string = "now"         # range to
    --format: string = "table"    # "table", "time_series", or "logs"
]: nothing -> any {
    let ds = (if ($uid | is-empty) { $CH_UID_DEFAULT } else { $uid })
    # grafana-clickhouse-datasource expects the FormatQueryOption enum as an int:
    # 0=time_series, 1=table, 2=logs, 3=trace.
    let fmt = ({ time_series: 0, table: 1, logs: 2, trace: 3 } | get -o $format | default 1)
    let payload = {
        queries: [
            {
                refId: "A"
                datasource: { type: $CH_DS_TYPE, uid: $ds }
                queryType: "sql"
                rawSql: $sql
                format: $fmt
                maxDataPoints: 5000
            }
        ]
        from: $start
        to: $end
    }
    _grafana-post "/api/ds/query" $payload
}

# Prometheus / PromQL. Instant by default; --range for a range query.
export def prom-query [
    expr: string
    --uid: string = ""            # Prometheus datasource UID (default: prod)
    --range                       # range query instead of instant
    --start: string = "now-1h"    # range only (relative or RFC3339/unix)
    --end: string = "now"         # range only
    --step: int = 60              # range only, seconds
]: nothing -> any {
    let ds = (if ($uid | is-empty) { $PROM_UID_DEFAULT } else { $uid })
    let base = $"/api/datasources/proxy/uid/($ds)/api/v1"
    let q = ($expr | url encode)
    if $range {
        _grafana-get $"($base)/query_range?query=($q)&start=($start)&end=($end)&step=($step)"
    } else {
        _grafana-get $"($base)/query?query=($q)"
    }
}

# grizzly (dashboards-as-code) with the token injected from 1Password on demand,
# so no stale token ever lands in grizzly's own config. Forwards all args/flags to
# the real `grr` binary. Examples:
#   grr pull dashboards/            # pull existing dashboards to files
#   grr apply -f my-dashboard.json  # push a new/edited dashboard
#   grr get Dashboard.<uid>         # fetch one
export def --wrapped grr [...args] {
    with-env { GRAFANA_URL: (_grafana-url), GRAFANA_TOKEN: (_grafana-token) } {
        ^grr ...$args
    }
}
