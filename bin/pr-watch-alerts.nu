# pr-watch-alerts.nu — event detection for bin/pr-watch (sourced, not run).
#
# pr-watch keeps a per-PR snapshot in its cache; comparing the previous poll's
# snapshot with this one yields at most ONE event per PR (Greg: "1 PR = 1 event"):
#   ci_fail   a check failed that was not failed before (second shard counts)
#   approval  a new login approved
#   comment   outstanding-comment count grew
#   ci_start  checks went from none pending to some pending
# A PR without a previous snapshot (first run, new PR, pre-alerts cache) yields
# nothing, so nothing rings on stale state. Tests: scripts/test-pr-watch-alerts.nu

const PR_ALERT_PRIORITY = {ci_fail: 0, approval: 1, comment: 2, ci_start: 3}

# Snapshot fields kept in the pr-watch cache for one `gh pr list` row.
def "pr-alert snapshot" [pr: record, out: int]: nothing -> record {
    let checks = ($pr | get -o statusCheckRollup | default [])
    let failed_checks = ($checks | where {|c|
        (($c | get -o conclusion | default "") in ["FAILURE" "TIMED_OUT" "STARTUP_FAILURE"]) or (($c | get -o state | default "") in ["FAILURE" "ERROR"])
    })
    let name_of = {|c| $c | get -o name | default ($c | get -o context | default "?") }
    let url_of = {|c| $c | get -o detailsUrl | default ($c | get -o targetUrl | default "") }
    {
        failed: ($failed_checks | each {|c| do $name_of $c } | uniq)
        failed_urls: ($failed_checks | reduce -f {} {|c, acc| $acc | upsert (do $name_of $c) (do $url_of $c) })
        pending: ($checks | any {|c|
            let st = ($c | get -o status | default "")
            (($st != "") and ($st != "COMPLETED")) or (($c | get -o state | default "") in ["PENDING" "EXPECTED"])
        })
        approvers: ($pr | get -o latestReviews | default [] | where {|r| ($r | get -o state) == "APPROVED" } | each {|r| $r | get -o author.login | default "?" } | uniq)
        outstanding: $out
    }
}

# Events between two caches keyed by PR number, at most one per PR.
def "pr-alert diff" [prev: record, cur: record, now: string]: nothing -> record {
    $cur | items {|key, c|
        let p = ($prev | get -o $key)
        if ($p == null) or ($p | get -o failed) == null or ($p | get -o pending) == null or ($p | get -o approvers) == null {
            return null
        }
        let num = ($key | into int)
        let new_failed = ($c.failed | where {|n| $n not-in $p.failed })
        let new_approvers = ($c.approvers | where {|l| $l not-in $p.approvers })
        let ev = (if ($new_failed | is-not-empty) {
            let n = ($new_failed | first)
            {kind: "ci_fail", text: $n, url: ($c.failed_urls | get -o $n | default "")}
        } else if ($new_approvers | is-not-empty) {
            {kind: "approval", text: ($new_approvers | str join ", "), url: ""}
        } else if $c.outstanding > ($p | get -o outstanding | default 0) {
            {kind: "comment", text: "", url: ""}
        } else if $c.pending and (not $p.pending) {
            {kind: "ci_start", text: "", url: ""}
        } else { null })
        if $ev == null { null } else { {key: $key, ev: ({ts: $now, num: $num} | merge $ev)} }
    } | compact | reduce -f {} {|r, acc| $acc | insert $r.key $r.ev }
}

# Fold new events into the unseen ones: a PR keeps one row, the more important
# kind wins, an equal kind is replaced by the newer one.
def "pr-alert merge" [old: record, new: record]: nothing -> record {
    $new | items {|k, v| {k: $k, v: $v} } | reduce -f $old {|r, acc|
        let o = ($acc | get -o $r.k)
        if ($o != null) and (($PR_ALERT_PRIORITY | get $o.kind) < ($PR_ALERT_PRIORITY | get $r.v.kind)) {
            $acc
        } else {
            $acc | upsert $r.k $r.v
        }
    }
}

# The one sound to play for a batch: the most important kind, or "".
def "pr-alert sound" [events: record]: nothing -> string {
    let kinds = ($events | values | get -o kind | default [])
    if ($kinds | is-empty) { return "" }
    $kinds | sort-by {|k| $PR_ALERT_PRIORITY | get $k } | first
}
