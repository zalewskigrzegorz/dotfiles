# workpr.nu — the shared PR CLASSIFIER + the `work pr` wrapper.
#
# The PR command center itself moved into the `workctl` binary
# (scriptc/workctl.ts) on 2026-09-18: registry, picker, every action. What stays
# here is the frozen classifier vocabulary (`work-pr signals` → `action` →
# `rank` / `bucket` / `classify`) because bin/prs and bin/pr-watch `source` this
# file for it, and a `work pr` def that hands off to workctl. workctl carries
# the SAME classifier in TypeScript; a change to one is a change to both.
#
# WHY THE FILENAME IS `workpr.nu` AND NOT `work-pr.nu`
#   Autoload files load in filename BYTE order and visibility is one-directional:
#   a later file sees an earlier file's defs, never the reverse, and the failure
#   is silent at load time — it only surfaces at call time as
#   ``Command `work` not found``. `work-pr.nu` sorts BEFORE `work.nu`
#   (`-` 0x2D < `.` 0x2E), so every `work repo-info` / `work worktree-path` /
#   `work _seed-untracked` call here would die at runtime. `workpr.nu` sorts
#   AFTER (`work.` < `workp`), so the primitives in work.nu are visible.
#   Consequence: `work pr` itself lives HERE, not in work.nu — work.nu cannot
#   call into this file.
#
# HEADLESS CALLERS (bin/prs, bin/pr-watch) source this file for the classifier;
# `nu -c` / `nu script.nu` load NO autoload dirs. gh-dash no longer needs the
# nu round-trip at all — its `T` calls `workctl --repo … --pr … --pause`.

# ── shared classifier (frozen vocabulary) ───────────────────────────────────
# `bin/prs` / `bin/pr-watch` call `work-pr action` / `work-pr classify` (they
# `source` this file — autoload does not reach a nu script). Ranks are chosen so
# bin/prs's current display order is preserved exactly:
#   MERGE(0) < needs review(2) < blocked(3) < fix CI(5) < changes req(7)
#   < draft(9) < draft+CI(10)
const WORKPR_RANK = {
    "MERGE": 0
    "resolve": 1
    "needs review": 2
    "blocked": 3
    "CI…": 4
    "fix CI": 5
    "conflict": 6
    "changes req": 7
    "run e2e": 8
    "draft": 9
    "draft+CI": 10
}

const WORKPR_BUCKET = {
    "MERGE": "merge"
    "resolve": "resolve"
    "needs review": "wait"
    "blocked": "wait"
    "CI…": "ci"
    "fix CI": "fix"
    "conflict": "fix"
    "changes req": "fix"
    "run e2e": "fix"
    "draft": "wip"
    "draft+CI": "wip"
}

const WORKPR_ACTIONABLE = ["MERGE" "resolve" "fix CI" "conflict" "changes req" "run e2e"]

# Pure — no I/O. statusCheckRollup is a UNION of two disjoint shapes:
# CheckRun (name/status/conclusion/detailsUrl/workflowName) and StatusContext
# (context/state/targetUrl/description). Reading only `.conclusion` misses
# failing legacy statuses; reading only `.name` yields null for StatusContext.
# The failure test is deliberately the BROAD one (matches bin/pr-brief).
# `| default []` matters: `null | where {…}` errors with "Input type not supported".
def "work-pr signals" [
    pr: record
    --me: string = ""
    --unresolved: any = null
    --outstanding: any = null
]: nothing -> record {
    let checks = ($pr | get -o statusCheckRollup | default [])
    let failed_rows = ($checks | where {|c|
        (($c | get -o conclusion | default "") == "FAILURE") or (($c | get -o state | default "") == "FAILURE")
    })
    let pending = ($checks | where {|c|
        let st = ($c | get -o status | default "")
        let state = ($c | get -o state | default "")
        (($st != "") and ($st != "COMPLETED")) or ($state in ["PENDING" "EXPECTED"])
    } | length)
    # e2e never started: a required StatusContext sits EXPECTED while no e2e
    # CheckRun is actually running — "E2E tests: skip by label" skipped it.
    let e2e_expected = ($checks | where {|c| ($c | get -o state | default "") == "EXPECTED"} | length)
    let e2e_running = ($checks | where {|c|
        let st = ($c | get -o status | default "")
        (($st != "") and ($st != "COMPLETED")) and (($c | get -o name | default "") =~ "(?i)e2e")
    } | length)
    let author = ($pr | get -o author.login | default "")
    {
        number: ($pr | get -o number | default 0)
        title: ($pr | get -o title | default "")
        url: ($pr | get -o url | default "")
        headRefName: ($pr | get -o headRefName | default "")
        headRefOid: ($pr | get -o headRefOid | default "")
        baseRefName: ($pr | get -o baseRefName | default "")
        isCrossRepository: ($pr | get -o isCrossRepository | default false)
        isDraft: ($pr | get -o isDraft | default false)
        author: $author
        isMine: (($me | is-not-empty) and ($author == $me))
        mergeable: ($pr | get -o mergeable | default "")
        mergeStateStatus: ($pr | get -o mergeStateStatus | default "")
        reviewDecision: ($pr | get -o reviewDecision | default "")
        labels: ($pr | get -o labels | default [] | each {|l| $l | get -o name | default "" })
        reviewRequests: ($pr | get -o reviewRequests | default [])
        latestReviews: ($pr | get -o latestReviews | default [])
        checks_total: ($checks | length)
        failed: ($failed_rows | length)
        failed_checks: ($failed_rows | each {|c|
            {
                name: ($c | get -o name | default ($c | get -o context | default "check"))
                url: ($c | get -o detailsUrl | default ($c | get -o targetUrl | default ""))
            }
        })
        pending: $pending
        e2e_expected: $e2e_expected
        e2e_running: $e2e_running
        unresolved: $unresolved
        outstanding: $outstanding
    }
}

# The 10-branch chain from bin/pr-watch plus the `resolve` post-pass. Multi-line
# `else if` only parses inside parentheses — a bare chain in a def body fails at
# parse time with ``Command `else` not found``.
# GATE: never emit `resolve` when `unresolved` is null, so `bin/prs` stays a
# single `gh pr list` call (the count needs one GraphQL query per PR).
# null is UNVERIFIED, not zero: 0 means "looked, nothing open", null means "nobody
# looked", and the only honest thing to do with unverified is decline to rule on it
# — never fold it into a clean count. Readers that must tell the two apart get
# `threads_fetched` from `work-pr _state`; MERGE-on-null is bin/prs's documented
# cheap path, not a claim that the conversations are clear.
def "work-pr action" [sig: record]: nothing -> string {
    let draft = ($sig | get -o isDraft | default false)
    let failed = ($sig | get -o failed | default 0)
    let pending = ($sig | get -o pending | default 0)
    let review = ($sig | get -o reviewDecision | default "")
    let mergeable = ($sig | get -o mergeable | default "")
    let e2e_expected = ($sig | get -o e2e_expected | default 0)
    let e2e_running = ($sig | get -o e2e_running | default 0)
    let unresolved = ($sig | get -o unresolved)
    let base = (
        if $draft and $failed > 0                            { "draft+CI" }
        else if $draft                                       { "draft" }
        else if $failed > 0                                  { "fix CI" }
        else if $mergeable == "CONFLICTING"                  { "conflict" }
        else if $review == "CHANGES_REQUESTED"               { "changes req" }
        else if $review == "REVIEW_REQUIRED"                 { "needs review" }
        else if ($e2e_expected > 0) and ($e2e_running == 0)  { "run e2e" }
        else if $pending > 0                                 { "CI…" }
        else if $mergeable == "MERGEABLE"                    { "MERGE" }
        else                                                 { "blocked" }
    )
    # GitHub blocks merge on ANY unresolved conversation → never claim MERGE
    # while threads are open; the action is to resolve them.
    if ($base == "MERGE") and ($unresolved != null) and ($unresolved > 0) { "resolve" } else { $base }
}

def "work-pr rank" [action: string]: nothing -> int {
    $WORKPR_RANK | get -o $action | default 99
}

def "work-pr bucket" [action: string]: nothing -> string {
    $WORKPR_BUCKET | get -o $action | default "wait"
}

def "work-pr actionable" [action: string]: nothing -> bool {
    $action in $WORKPR_ACTIONABLE
}

def "work-pr classify" [
    pr: record
    --me: string = ""
    --unresolved: any = null
    --outstanding: any = null
]: nothing -> record {
    let sig = (work-pr signals $pr --me $me --unresolved $unresolved --outstanding $outstanding)
    let a = (work-pr action $sig)
    $sig | merge {
        action: $a
        actionable: (work-pr actionable $a)
        rank: (work-pr rank $a)
        bucket: (work-pr bucket $a)
    }
}

# `work pr` — hands off to workctl. Positional / --pr / --repo / --action and the
# rest pass straight through; `workctl --help` lists them.
def --wrapped "work pr" [...rest]: nothing -> nothing {
    ^workctl ...$rest
}
