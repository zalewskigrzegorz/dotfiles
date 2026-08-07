# workpr.nu — `work pr`: the PR command center (intent-first menu over one PR).
#
# One entry point that resolves a PR, reads its state ONCE, and offers an
# intent-first, state-sorted fzf menu. Picking an intent runs the whole flow —
# gh chores, worktree checkout, or a claude session already briefed on the PR.
# Adding a capability = appending one record to `work-pr registry`.
#
# Absorbs everything `bin/pr-menu` did (resolve review threads, toggle CI
# labels) with its defensive behaviour intact — see the RISK comments below;
# every one of them is a bug that was already paid for once.
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
# HEADLESS CALLERS MUST SOURCE BOTH FILES, PRIMITIVES FIRST
#   `nu -c` / `nu script.nu` / `#!/usr/bin/env nu` load NO autoload dirs at all:
#     nu -c 'source ~/.config/nushell/autoload/work.nu; source ~/.config/nushell/autoload/workpr.nu; work pr --pr N --repo owner/name --pause'
#   Wrong order parses fine and fails only at call time, so it passes every
#   interactive smoke test and breaks only from gh-dash. Verify by pressing `T`.
#
# Failures raise `error make --unspanned` (exit 1), never `exit` — `work pr` runs
# in Greg's interactive REPL and `exit 1` would close his shell.

# Shorthands only. Anything not listed is used verbatim as a label name, so this
# is not welded to these three. Insertion order drives the label row order.
const WORKPR_LABEL_ALIASES = {
    nc: "no-changeset-needed"
    e2e: "run_e2e"
    skip: "skip_e2e"
}

# One `gh pr view --json` for the whole run. All 16 verified present in gh
# 2.97.0's 44-field list. `stack` and `reviewThreads` are NOT there and never
# will be — both are GraphQL-only.
const WORKPR_VIEW_FIELDS = "number,title,url,isDraft,author,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,labels,reviewRequests,latestReviews,headRefName,headRefOid,baseRefName,isCrossRepository"

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

# ── plumbing ────────────────────────────────────────────────────────────────

def "work-pr _hold" []: nothing -> nothing {
    print ""
    # No TTY means nothing is about to reclaim the screen, so a failed read is fine.
    try { input "press enter to continue" | ignore }
}

# gh-dash repaints the dashboard the moment the child exits, so an error message
# needs the same hold as a success message. WORK_PR_PAUSE is set as `work pr`'s
# FIRST statement — an env var, not a parameter, because nested defs have no
# access to the dispatcher's --pause switch and would silently lose the hold.
def "work-pr _die" [msg: string] {
    print -e $msg
    if ($env.WORK_PR_PAUSE? | default "0") == "1" { work-pr _hold }
    error make --unspanned {msg: "work pr aborted"}
}

# ── target resolution (moved from bin/pr-menu unchanged) ─────────────────────

def "work-pr _cwd-repo" []: nothing -> string {
    let r = (do { ^gh repo view --json nameWithOwner } | complete)
    if $r.exit_code != 0 { work-pr _die ($r.stderr | str trim) }
    $r.stdout | from json | get nameWithOwner
}

def "work-pr _branch-pr" []: nothing -> int {
    # No --repo on purpose: `gh pr view` rejects --repo without a PR argument, and
    # it is cwd detection that turns the current branch into a PR number.
    let r = (do { ^gh pr view --json number } | complete)
    if $r.exit_code != 0 { work-pr _die ($r.stderr | str trim) }
    $r.stdout | from json | get number
}

# GraphQL wants owner and name as separate variables, so an empty --repo cannot
# just be omitted the way it can for `gh pr view` — resolve once, reuse everywhere.
#
# --repo + --pr makes ZERO gh calls, which is what lets the gh-dash binding work
# from any cwd for repos absent from repoPaths. --repo without --pr MUST call
# _cwd-repo and die on mismatch: the branch only names a PR in the repo we are
# standing in, so mixing the two would apply a local PR number to somebody
# else's repository.
def "work-pr _resolve-target" [repo_flag: string, pr_flag: int]: nothing -> record {
    if $repo_flag == "" {
        return {repo: (work-pr _cwd-repo), num: (if $pr_flag != 0 { $pr_flag } else { work-pr _branch-pr })}
    }
    if $pr_flag != 0 { return {repo: $repo_flag, num: $pr_flag} }
    let here = (work-pr _cwd-repo)
    if $here != $repo_flag {
        work-pr _die $"--repo ($repo_flag) needs an explicit --pr — branch detection only speaks for ($here)"
    }
    {repo: $repo_flag, num: (work-pr _branch-pr)}
}

# Menu-path target: positional / --pr → PR of the current branch → fzf over
# `gh pr list` (the old `work pr`'s behaviour, which had no branch detection).
# The picker is only reachable with a TTY, so the headless contract that
# `_resolve-target` defines is untouched — everything else goes straight there,
# including the two dies whose text and relative order headless callers see.
def "work-pr _resolve-menu-target" [repo_flag: string, pr_flag: int]: nothing -> record {
    if ($repo_flag == "") and ($pr_flag == 0) and (is-terminal --stdin) {
        let repo = (work-pr _cwd-repo)
        let b = (do { ^gh pr view --json number } | complete)
        if $b.exit_code == 0 { return {repo: $repo, num: ($b.stdout | from json | get number)} }
        return {repo: $repo, num: (work-pr _pick-pr $repo)}
    }
    work-pr _resolve-target $repo_flag $pr_flag
}

# fzf over open PRs. Returns 0 when nothing was picked.
def "work-pr _pick-pr" [repo: string]: nothing -> int {
    if (which fzf | is-empty) { work-pr _die "pass a PR number (fzf not on PATH)" }
    let l = (do { ^gh pr list --repo $repo --limit 50 --json number,title,headRefName --jq '.[] | "\(.number)\t\(.title)\t\(.headRefName)"' } | complete)
    if $l.exit_code != 0 { work-pr _die ($l.stderr | str trim) }
    if ($l.stdout | str trim | is-empty) { work-pr _die $"no open PRs in ($repo)" }
    let r = (do { $l.stdout | ^fzf --delimiter "\t" --with-nth "1,2,3" --reverse --prompt "PR: " } | complete)
    if $r.exit_code in [1 130] { return 0 }
    if $r.exit_code != 0 { work-pr _die $"fzf failed \(($r.exit_code)\): ($r.stderr | str trim)" }
    let picked = ($r.stdout | str trim)
    if ($picked | is-empty) { return 0 }
    $picked | split row "\t" | first | into int
}

# ── state: one gh pr view + at most one GraphQL round trip ───────────────────

# Viewer login. Override with $env.WORK_PR_ME to skip the API call (nushell env
# is block-scoped, so a def cannot memoize it for the caller).
def "work-pr _me" []: nothing -> string {
    let from_env = ($env.WORK_PR_ME? | default "")
    if ($from_env | is-not-empty) { return $from_env }
    let r = (do { ^gh api user --jq .login } | complete)
    if $r.exit_code != 0 { return "" }
    $r.stdout | str trim
}

def "work-pr _pr-view" [repo: string, num: int]: nothing -> record {
    let r = (do { ^gh pr view $num --repo $repo --json $WORKPR_VIEW_FIELDS } | complete)
    if $r.exit_code != 0 { work-pr _die ($r.stderr | str trim) }
    $r.stdout | from json
}

# Repo labels. `gh label list --json name` returns a TOP-LEVEL ARRAY, unlike
# `gh pr view --json labels` (object with a `labels` key) — the two parse paths
# are intentionally different, do not unify them.
# --limit 1000 is load-bearing: `gh label list` defaults to 30 and even 200 cuts
# off label-heavy repos (vscode has 710), which turns a real label into a bogus
# "does not exist" die. Empty stdout is gh's no-results path, hence `default []`.
def "work-pr _repo-labels" [repo: string]: nothing -> list<string> {
    let r = (do { ^gh label list --repo $repo --json name --limit 1000 } | complete)
    if $r.exit_code != 0 { work-pr _die ($r.stderr | str trim) }
    $r.stdout | from json | default [] | each {|l| $l | get -o name | default "" }
}

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

# reviewThreads is GraphQL-only — `gh pr view --json` has no such field.
def "work-pr _threads" [owner: string, name: string, num: int]: nothing -> record {
    let q = 'query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){pullRequest(number:$num){reviewThreads(first:100){totalCount pageInfo{hasNextPage} nodes{id isResolved path line originalLine comments(first:1){nodes{author{login} body url}}}}}}}'
    # -f, not -F, for the String! variables: -F type-coerces, so an all-digit owner
    # or repo name (owner/2048) would go out as an Int and be rejected. `num` MUST
    # be -F because the GraphQL variable is Int!.
    let r = (do {
        ^gh api graphql -f $"query=($q)" -f $"owner=($owner)" -f $"name=($name)" -F $"num=($num)"
    } | complete)
    if $r.exit_code != 0 { work-pr _die $"failed to read review threads: ($r.stderr | str trim)" }
    let t = ($r.stdout | from json | get -o data.repository.pullRequest.reviewThreads)
    {
        # Missing isResolved counts as resolved — never mutate a thread we cannot
        # read. `default true` is safe ONLY because nushell's `default` does not
        # replace a literal `false`. Swap it for `?? true`, `default --empty true`
        # or a JS-style truthiness check and EVERY resolved thread becomes
        # "unresolved", so the tool re-mutates the whole page.
        unresolved: ($t | get -o nodes | default [] | where {|n| not ($n | get -o isResolved | default true)}),
        truncated: ($t | get -o pageInfo.hasNextPage | default false),
        total: ($t | get -o totalCount | default 0),
    }
}

# Stack membership. Also GraphQL-only, and also absent from `gh pr view --json`.
# Verified against the live schema on 2026-07-31 (gh 2.97.0, no preview header
# needed): PullRequest.stack → PullRequestStack{id number size baseRefName entries}
# and PullRequest.stackEntry → PullRequestStackEntry{id position stack pullRequest}.
# A PR outside a stack returns `stack: null` / `stackEntry: null`, which is the
# whole detection.
#
# ITS OWN ROUND TRIP ON PURPOSE — never fold these fields into `_threads`. `stack`
# is public preview: an API that does not know the field rejects the WHOLE document
# ("Field 'stack' doesn't exist"), which would take conversation resolution down
# with it. Here the worst case is null.
# Every failure path returns null = "no stack known", never a die: this only decides
# whether the 🥞 row sorts as relevant, and an irrelevant row is still pickable.
def "work-pr _stack" [owner: string, name: string, num: int]: nothing -> any {
    let q = 'query($owner:String!,$name:String!,$num:Int!){repository(owner:$owner,name:$name){pullRequest(number:$num){stack{number size baseRefName} stackEntry{position}}}}'
    # -f/-F for the same reason as _threads: an all-digit owner must stay a String.
    let r = (do {
        ^gh api graphql -f $"query=($q)" -f $"owner=($owner)" -f $"name=($name)" -F $"num=($num)"
    } | complete)
    if $r.exit_code != 0 { return null }
    let pr = (try { $r.stdout | from json | get -o data.repository.pullRequest } catch { null })
    if $pr == null { return null }
    let s = ($pr | get -o stack)
    if $s == null { return null }
    {
        number: ($s | get -o number | default 0)
        size: ($s | get -o size | default 0)
        baseRefName: ($s | get -o baseRefName | default "")
        position: ($pr | get -o stackEntry.position | default 0)
    }
}

# The single pr-state record. `--no-threads` skips the GraphQL round trip for
# actions that do not need it, mirroring pr-menu's conditional fetch. One fetch
# shared by the menu annotations and the mutations, so the number Greg read
# cannot disagree with the set that gets mutated.
#
# ORDER IS LOAD-BEARING: threads are fetched BEFORE `classify` and handed to it as
# `--unresolved`. Classifying first (what this used to do) left the classifier's
# `resolve` state permanently dead on this path — its gate is `unresolved != null`
# — so `--json` cheerfully reported `action: MERGE / actionable: true` right next
# to `unresolved: 3`, which GitHub will not merge. bin/pr-watch does it in this
# order for the same reason.
#
# NOT-FETCHED IS NOT ZERO: with `--no-threads` the count is `null`, never 0, and
# `threads_fetched` says so outright. A `0` there would be indistinguishable from
# a genuinely clean PR — for a reader of `--json` and, worse, for the classifier,
# which would then be free to claim MERGE on a PR whose threads nobody looked at.
def "work-pr _state" [repo: string, num: int, --no-threads]: nothing -> record {
    let parts = ($repo | split row "/")
    let pr = (work-pr _pr-view $repo $num)
    let th = (if $no_threads { null } else { work-pr _threads $parts.0 $parts.1 $num })
    # Rides the same `--no-threads` switch: the gh-only fast paths (a label toggle,
    # `copy`) skip it, and the menu — the only reader of the 🥞 row's relevance —
    # always fetches. Note the fast path is TWO gh calls, not one: `_me` below also
    # goes out. It is not skipped there on purpose — `action` would then differ
    # between a headless `--json` run and the menu, which is exactly the drift the
    # shared classifier exists to prevent. Export `WORK_PR_ME=<login>` to cut it.
    let stk = (if $no_threads { null } else { work-pr _stack $parts.0 $parts.1 $num })
    let n_unresolved = (if $th == null { null } else { $th.unresolved | length })
    let c = (work-pr classify $pr --me (work-pr _me) --unresolved $n_unresolved)
    $c | merge {
        repo: $repo
        owner: $parts.0
        name: $parts.1
        num: $num
        threads_fetched: ($th != null)
        unresolved: $n_unresolved
        unresolved_threads: (if $th == null { [] } else { $th.unresolved })
        threads_truncated: (if $th == null { false } else { $th.truncated })
        threads_total: (if $th == null { null } else { $th.total })
        # repoRoot / worktreePath are resolved ON DEMAND by `work-pr _require-local`,
        # never here: the gh-only path must not make a single git call (that is what
        # lets `--repo owner/name --pr N` work from any cwd, including repos gh-dash
        # has no repoPath for), and a path keyed off cwd alone is worse than none.
        repoRoot: null
        worktreePath: null
        # {number, size, baseRefName, position} when this PR is a stack member, else
        # null. null also means "not read" on the `--no-threads` paths — same
        # convention as `unresolved`, and `threads_fetched` distinguishes the two.
        stack: $stk
    }
}

# `unresolved` is null when the GraphQL fetch was skipped, and `null > 0` is a hard
# error in nushell ("can't convert nothing to boolean"), so every boolean/display
# reader goes through here. Unknown renders as "none to show"; whether unknown is
# safe to merge on is the classifier's call, and it sees the null itself.
def "work-pr _unresolved-n" [st: record]: nothing -> int {
    $st | get -o unresolved | default 0
}

# ── local checkout reconciliation ────────────────────────────────────────────
# Nothing below runs on the GitHub-only path. `--repo owner/name --pr N` (what the
# gh-dash `T` binding passes for EVERY repo in the dash) makes zero git calls, so
# a repo that is only in the dash and not on disk still works from any cwd.

# owner/name of every remote in the cwd checkout — `git config`, so local only, no
# network and no gh call. `https://host/o/n.git`, `git@host:o/n.git` and
# `ssh://git@host/o/n` all reduce to `o/n`; --local keeps a stray global
# `remote.*.url` out of the answer.
def "work-pr _cwd-repo-ids" []: nothing -> list<string> {
    let r = (do { ^git config --local --get-regexp '^remote\..+\.url$' } | complete)
    if $r.exit_code != 0 { return [] }
    $r.stdout | lines | each {|l|
        let url = ($l | split row " " | skip 1 | str join " " | str trim)
        let segs = ($url | str replace -r '\.git$' "" | split row -r '[/:]' | where {|s| $s != ""})
        if ($segs | length) >= 2 { $segs | last 2 | str join "/" | str lowercase } else { "" }
    } | where {|s| $s != ""} | uniq
}

# cwd → the PR's checkout. `root`/`worktree` are EMPTY unless cwd really is a
# checkout of `repo`; `cwdRepo` names what cwd actually is, for the error message.
#
# This used to resolve `worktree` from the BRANCH NAME alone against whatever
# `work repo-info` returned, never comparing it to the PR's repo. With
# `--repo owner/name --pr N` that made every local action — worktree creation, the
# agent intents, `gh stack`, and `kick`'s empty commit AND PUSH — operate on the
# repository the shell happened to be sitting in. Fork PRs off master/main collide
# constantly, so this compares and never falls back.
def "work-pr _local-checkout" [repo: string, head: string]: nothing -> record {
    # `work repo-info` hard-errors outside a git repo, and the gh-dash path can
    # legitimately run from $HOME.
    let info = (try { work repo-info } catch { null })
    if $info == null { return {cwdRepo: "", root: "", worktree: ""} }
    let ids = (work-pr _cwd-repo-ids)
    # A fork PR's `--repo` is the BASE repo, which is also the repo Greg has cloned,
    # so matching any remote (origin or upstream) is right — matching none is not.
    # GitHub repo names are case-insensitive, so compare lowercased.
    if not (($repo | str lowercase) in $ids) {
        return {cwdRepo: ($ids | get -o 0 | default ""), root: "", worktree: ""}
    }
    {
        cwdRepo: $repo
        root: $info.root
        worktree: (if ($head | is-empty) { "" } else { work _checkout-path $info.root $head })
    }
}

# Names BOTH sides — a silent fallback to cwd's repo is the bug this exists to
# prevent, and the message is identical whether the caller dies or just fails.
def "work-pr _local-miss-msg" [st: record, loc: record, what: string]: nothing -> string {
    let here = (
        if ($loc.cwdRepo | is-empty) { $"($env.PWD) is not a git checkout" }
        else { $"($env.PWD) is a checkout of ($loc.cwdRepo)" }
    )
    $"($what) needs a local checkout of ($st.repo) — ($here). cd into ($st.repo) first, or pick a gh-only action."
}

# The gate the terminal-taking actions (worktree / agent) go through: they own the
# screen from here on, so raising is fine.
def "work-pr _require-local" [st: record, what: string]: nothing -> record {
    let loc = (work-pr _local-checkout $st.repo ($st | get -o headRefName | default ""))
    if ($loc.root | is-empty) {
        work-pr _die (work-pr _local-miss-msg $st $loc $what)
    }
    $loc
}

# Same gate for actions that are just one row of a TAB multi-selection: returns
# null instead of raising, so `kick` failing cannot cancel the label toggle and the
# worktree that were picked alongside it. Every other action already reports a
# failure COUNT for exactly that reason; these two used to `_die` and abort the
# whole plan.
def "work-pr _try-local-worktree" [st: record, what: string, hint: string]: nothing -> any {
    let loc = (work-pr _local-checkout $st.repo ($st | get -o headRefName | default ""))
    if ($loc.root | is-empty) {
        print -e (work-pr _local-miss-msg $st $loc $what)
        return null
    }
    if ($loc.worktree | is-empty) {
        print -e $hint
        return null
    }
    $loc
}

# ── actions — every one returns a failure count ──────────────────────────────

# Returns how many threads failed — one bad thread must not abort the rest.
def "work-pr _do-resolve" [st: record, dry: bool]: nothing -> int {
    # Warn BEFORE the empty check: a PR whose first 100 threads are all resolved
    # still has an unresolved tail, and re-running cannot reach it (first:100 with
    # no cursor refetches the same page), so never report that as clean.
    if $st.threads_truncated {
        print -e "more than 100 review threads here — only the first 100 were handled; resolve the tail in the web UI"
    }
    if ($st.unresolved_threads | is-empty) {
        print "nothing to resolve"
        return 0
    }
    if $dry {
        print $"[dry-run] gh api graphql resolveReviewThread × ($st.unresolved_threads | length)"
        return 0
    }
    let m = 'mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}'
    mut failed = []
    for t in $st.unresolved_threads {
        let r = (do { ^gh api graphql -f $"query=($m)" -f $"id=($t.id)" } | complete)
        # gh exits non-zero on GraphQL errors, but a 200-with-errors body would
        # slip past the exit code alone. The try/catch is required too — empty or
        # non-JSON stdout would otherwise raise.
        let errs = (try { $r.stdout | from json | get -o errors | default [] } catch { [] })
        if ($r.exit_code != 0) or ($errs | is-not-empty) {
            let why = if ($errs | is-not-empty) {
                $errs | each {|e| $e | get -o message | default "?" } | str join "; "
            } else {
                $r.stderr | str trim
            }
            $failed = ($failed | append {id: $t.id, why: $why})
        }
    }
    let total = ($st.unresolved_threads | length)
    print $"resolved (($total) - ($failed | length))/($total) conversations"
    for f in $failed { print -e $"failed ($f.id): ($f.why)" }
    $failed | length
}

# `current` is the SINGLE label snapshot taken once per run (from the one
# `gh pr view`) and reused for every toggle in a TAB batch — deliberately not
# refetched between toggles.
def "work-pr _do-label" [st: record, label: string, current: list<string>, dry: bool]: nothing -> int {
    let on = ($label in $current)
    let flag = if $on { "--remove-label" } else { "--add-label" }
    if $dry {
        print $"[dry-run] gh pr edit ($st.num) --repo ($st.repo) ($flag) ($label)"
        return 0
    }
    let r = (do { ^gh pr edit $st.num --repo $st.repo $flag $label } | complete)
    if $r.exit_code != 0 {
        print -e $"($flag) ($label) failed: ($r.stderr | str trim)"
        return 1
    }
    print (if $on { $"- ($label)" } else { $"+ ($label)" })
    0
}

# Validate every label before the FIRST write: a bad key in a TAB multi-select
# would otherwise half-apply the batch. One `gh label list` for the whole run.
def "work-pr _validate-labels" [repo: string, wanted: list<string>]: nothing -> nothing {
    if ($wanted | is-empty) { return }
    let known = (work-pr _repo-labels $repo)
    let missing = ($wanted | where {|n| not ($n in $known)})
    if ($missing | is-not-empty) {
        work-pr _die ($missing | each {|n| $"label '($n)' does not exist in ($repo)" } | str join (char newline))
    }
}

def "work-pr _confirm" [summary: string, yes: bool]: nothing -> bool {
    if $yes { return true }
    if not (is-terminal --stdin) { work-pr _die $"($summary) needs --yes when stdin is not a TTY" }
    print -e $summary
    let ans = (input "proceed? [y/N]: " | str trim | str lowercase)
    $ans == "y"
}

def "work-pr _do-diff" [st: record, dry: bool]: nothing -> int {
    if $dry { print $"[dry-run] gh pr diff ($st.num) --repo ($st.repo)"; return 0 }
    ^gh pr diff $st.num --repo $st.repo
    0
}

def "work-pr _do-web" [st: record, dry: bool]: nothing -> int {
    if $dry { print $"[dry-run] gh pr view ($st.num) --repo ($st.repo) --web"; return 0 }
    let r = (do { ^gh pr view $st.num --repo $st.repo --web } | complete)
    if $r.exit_code != 0 { print -e $"open in browser failed: ($r.stderr | str trim)"; return 1 }
    0
}

def "work-pr _do-copy" [st: record, dry: bool]: nothing -> int {
    if $dry { print $"[dry-run] copy ($st.url)"; return 0 }
    if (which pbcopy | is-empty) { print $st.url; return 0 }
    $st.url | ^pbcopy
    print $st.url
    0
}

# Read-only, no gh call — everything comes from the single state fetch.
def "work-pr _do-blockers" [st: record]: nothing -> int {
    print $"#($st.num) ($st.title)"
    print $"  mergeStateStatus : ($st.mergeStateStatus)"
    print $"  mergeable        : ($st.mergeable)"
    print $"  reviewDecision   : ($st.reviewDecision)"
    let unresolved = (work-pr _unresolved-n $st)
    # Built in steps, not nested interpolations: `\(` inside an INNER $"…" is not an
    # escape, it reaches stdout as a literal backslash.
    let cap = (if $st.threads_truncated { "+ (capped at 100)" } else { "" })
    let unres_txt = (
        if ($st | get -o threads_fetched | default true) { $"($unresolved)($cap)" } else { "not fetched" }
    )
    print $"  unresolved       : ($unres_txt)"
    print $"  checks           : ($st.failed) failed · ($st.pending) pending · ($st.checks_total) total"
    print $"  draft            : ($st.isDraft)"
    print ""
    mut blockers = []
    if $st.isDraft { $blockers = ($blockers | append "PR is a draft — 📤 ready for review") }
    if $st.mergeable == "CONFLICTING" { $blockers = ($blockers | append "merge conflict — ⬆️ update branch, or rebase by hand") }
    if $st.mergeStateStatus == "BEHIND" { $blockers = ($blockers | append "branch is behind base — ⬆️ update branch") }
    if $st.failed > 0 { $blockers = ($blockers | append $"($st.failed) failing check\(s) — 🔍 logs / ♻️ rerun / 🔧 fix-ci") }
    if $st.pending > 0 { $blockers = ($blockers | append $"($st.pending) check\(s) still running — 👁 watch") }
    if ($st.e2e_expected > 0) and ($st.e2e_running == 0) { $blockers = ($blockers | append "e2e expected but not running — 🏷 run_e2e") }
    if $unresolved > 0 { $blockers = ($blockers | append $"($unresolved) unresolved conversation\(s) — ✅ resolve / 💬 respond") }
    if $st.reviewDecision == "CHANGES_REQUESTED" { $blockers = ($blockers | append "changes requested — 🔔 re-review after fixing") }
    if $st.reviewDecision == "REVIEW_REQUIRED" { $blockers = ($blockers | append "review required — waiting on reviewers") }
    if ($blockers | is-empty) {
        print "no blockers found — 🚀 merge should go through"
    } else {
        for b in $blockers { print $"✗ ($b)" }
    }
    0
}

# `--undo` is plan-gated: `gh pr ready --help` says "If supported by your plan,
# convert to draft with --undo", so only the draft direction can fail that way.
def "work-pr _do-ready" [st: record, dry: bool]: nothing -> int {
    if $st.isDraft {
        if $dry { print $"[dry-run] gh pr ready ($st.num) --repo ($st.repo)"; return 0 }
        let r = (do { ^gh pr ready $st.num --repo $st.repo } | complete)
        if $r.exit_code != 0 { print -e $"ready for review failed: ($r.stderr | str trim)"; return 1 }
        print $"📤 #($st.num) ready for review"
        return 0
    }
    if $dry { print $"[dry-run] gh pr ready ($st.num) --repo ($st.repo) --undo"; return 0 }
    let r = (do { ^gh pr ready $st.num --repo $st.repo --undo } | complete)
    if $r.exit_code != 0 {
        print -e $"back to draft failed \(plan may not support draft conversion\): ($r.stderr | str trim)"
        return 1
    }
    print $"📥 #($st.num) back to draft"
    0
}

def "work-pr _do-merge" [st: record, yes: bool, dry: bool]: nothing -> int {
    if $dry { print $"[dry-run] gh pr merge ($st.num) --repo ($st.repo) --squash --auto"; return 0 }
    if not (work-pr _confirm $"merge #($st.num) --squash --auto into ($st.baseRefName)?" $yes) {
        print -e "merge skipped"
        return 0
    }
    let r = (do { ^gh pr merge $st.num --repo $st.repo --squash --auto } | complete)
    if $r.exit_code != 0 { print -e $"merge failed: ($r.stderr | str trim)"; return 1 }
    print $"🚀 #($st.num) squash+auto merge armed"
    0
}

# `gh pr update-branch` defaults to a MERGE COMMIT; --rebase rewrites history and
# force-pushes. Two rows on purpose, and the rebase confirm must say force-push.
def "work-pr _do-update-branch" [st: record, rebase: bool, yes: bool, dry: bool]: nothing -> int {
    if $dry {
        print $"[dry-run] gh pr update-branch ($st.num) --repo ($st.repo)(if $rebase { ' --rebase' } else { '' })"
        return 0
    }
    if $rebase {
        if not (work-pr _confirm $"update #($st.num) by REBASE onto ($st.baseRefName) — this force-pushes ($st.headRefName)" $yes) {
            print -e "update skipped"
            return 0
        }
    }
    let r = (
        if $rebase {
            do { ^gh pr update-branch $st.num --repo $st.repo --rebase } | complete
        } else {
            do { ^gh pr update-branch $st.num --repo $st.repo } | complete
        }
    )
    if $r.exit_code != 0 { print -e $"update-branch failed: ($r.stderr | str trim)"; return 1 }
    print $"⬆️ #($st.num) updated from ($st.baseRefName)"
    0
}

# `gh pr edit --add-reviewer` re-requests an existing reviewer ("Add or
# re-request reviewers by their login"), so this is the whole implementation.
def "work-pr _do-re-review" [st: record, dry: bool]: nothing -> int {
    let logins = (
        $st | get -o latestReviews | default []
        | where {|r| ($r | get -o state | default "") == "CHANGES_REQUESTED"}
        | each {|r| $r | get -o author.login | default "" }
        | where {|l| $l != ""}
        | uniq
    )
    if ($logins | is-empty) { print "no changes-requested reviewers"; return 0 }
    let joined = ($logins | str join ",")
    if $dry { print $"[dry-run] gh pr edit ($st.num) --repo ($st.repo) --add-reviewer ($joined)"; return 0 }
    let r = (do { ^gh pr edit $st.num --repo $st.repo --add-reviewer $joined } | complete)
    if $r.exit_code != 0 { print -e $"re-review failed: ($r.stderr | str trim)"; return 1 }
    print $"🔔 re-requested: ($joined)"
    0
}

# Requested reviewers as picker rows. gh flattens `requestedReviewer` one level up
# and emits EXACTLY three keys for a Team — {__typename, name, slug} — plus
# {__typename, login} for a User (verified in cli/cli api/export_pr.go, gh 2.97.0).
#
# TWO TRAPS, both paid for once:
#   1. There is NO `organization` key in the exported row (gh keeps
#      `Organization.Login` on its internal struct and never marshals it), so
#      `organization.login` rendered every team as `?/…` in the picker.
#   2. `slug` is NOT the bare slug: export calls `RequestedReviewer.LoginOrSlug()`,
#      which returns `fmt.Sprintf("%s/%s", org.Login, slug)` for a Team. That
#      org-qualified form is what `gh pr edit --add-reviewer` wants, but
#      `DELETE …/requested_reviewers` documents `team_reviewers` as "An array of
#      team slugs that will be removed" — BARE. Sending `acme/some-team` there
#      removes nothing; `some-team` is what the endpoint takes.
# So `id` is the bare slug (what the DELETE takes), `display` keeps the readable
# org-qualified name, and `match` accepts either spelling from --drop.
def "work-pr _reviewer-rows" [st: record]: nothing -> list<record> {
    $st | get -o reviewRequests | default [] | each {|r|
        let kind = ($r | get -o __typename | default "")
        if $kind == "Team" {
            let qualified = ($r | get -o slug | default "")
            # `last` handles both spellings, so a gh that ever stops qualifying the
            # slug keeps working.
            let bare = ($qualified | split row "/" | last)
            let name = ($r | get -o name | default "")
            {
                key: $"team:($bare)"
                kind: "team"
                id: $bare
                match: [$bare $qualified $"team:($bare)" $"team:($qualified)"]
                display: (if ($name | is-empty) { $qualified } else { $"($qualified) \(($name)\)" })
            }
        } else {
            let login = ($r | get -o login | default "")
            {key: $"user:($login)", kind: "user", id: $login, match: [$login $"user:($login)"], display: $login}
        }
    } | where {|it| ($it.id | is-not-empty)}
}

# --drop takes comma-separated team slugs (or user logins). Empty --drop on a TTY
# opens a sub-picker over the requested reviewers.
def "work-pr _do-trim" [st: record, drop: string, dry: bool]: nothing -> int {
    let rows = (work-pr _reviewer-rows $st)
    if ($rows | is-empty) { print "no requested reviewers"; return 0 }
    let endpoint = $"repos/($st.owner)/($st.name)/pulls/($st.num)/requested_reviewers"
    # Describe the plan BEFORE building the picked set: without --drop the set comes
    # from the fzf sub-picker, which the TTY guard refuses headlessly, so a --dry-run
    # from a script (the documented verification path) used to die instead of
    # printing anything.
    if $dry and ($drop | is-empty) {
        print $"[dry-run] pick reviewers to drop from (($rows | get display | str join ', ')) → gh api -X DELETE ($endpoint)"
        return 0
    }
    let picked = (
        if ($drop | is-not-empty) {
            let wanted = ($drop | split row "," | each {|d| $d | str trim } | where {|d| $d != ""})
            let hit = ($rows | where {|r| ($wanted | any {|w| $w in $r.match})})
            let missing = ($wanted | where {|w| not ($rows | any {|r| $w in $r.match})})
            if ($missing | is-not-empty) {
                print -e $"not a requested reviewer: (($missing | str join ', ')) — requested: (($rows | get display | str join ', '))"
                return 1
            }
            $hit
        } else {
            let keys = (work-pr _fzf ($rows | each {|r| $"($r.key)\t✂️  ($r.display | fill -w 34) [($r.kind)]" }) "trim reviewer> " $"($st.repo) #($st.num) — TAB for multiple")
            $rows | where {|r| $r.key in $keys}
        }
    )
    if ($picked | is-empty) { print -e "nothing to trim"; return 0 }
    let args = (
        $picked | each {|r|
            if $r.kind == "team" { ["-f" $"team_reviewers[]=($r.id)"] } else { ["-f" $"reviewers[]=($r.id)"] }
        } | flatten
    )
    if $dry { print $"[dry-run] gh api -X DELETE ($endpoint) (($args | str join ' '))"; return 0 }
    # -X DELETE must be EXPLICIT: any -f auto-switches the method to POST, which
    # would ADD the reviewers instead of removing them.
    let r = (do { ^gh api -X DELETE $endpoint ...$args } | complete)
    if $r.exit_code != 0 { print -e $"trim failed: ($r.stderr | str trim)"; return 1 }
    print $"✂️ trimmed: (($picked | get display | str join ', '))"
    0
}

# Actions run id for the PR head. Only `/actions/runs/(\d+)` counts — a
# non-Actions check's link is .../runs/<check-run-id>, which 404s on `gh run`.
def "work-pr _run-id" [st: record]: nothing -> string {
    if ($st.headRefOid | is-not-empty) {
        let r = (do { ^gh run list --repo $st.repo --commit $st.headRefOid --json databaseId,event,workflowName,conclusion -L 20 } | complete)
        if $r.exit_code == 0 {
            let runs = (try { $r.stdout | from json | default [] } catch { [] })
            let m = ($runs | where {|x| ($x | get -o event | default "") == "pull_request"})
            if ($m | is-not-empty) { return (($m | first | get databaseId) | into string) }
            if ($runs | is-not-empty) { return (($runs | first | get databaseId) | into string) }
        }
    }
    let ids = (
        $st | get -o failed_checks | default [] | get url
        | each {|u| $u | parse --regex '/actions/runs/(?P<id>[0-9]+)' | get -o id.0 | default "" }
        | where {|i| $i != ""}
    )
    if ($ids | is-empty) { "" } else { $ids | first }
}

def "work-pr _do-logs" [st: record, dry: bool]: nothing -> int {
    let id = (work-pr _run-id $st)
    if ($id | is-empty) {
        print -e $"no Actions run found for ($st.headRefOid) — open the check in the browser"
        return 1
    }
    if $dry { print $"[dry-run] gh run view ($id) --repo ($st.repo) --log-failed"; return 0 }
    ^gh run view $id --repo $st.repo --log-failed
    0
}

# `gh run rerun` with no run id and no TTY exits 1 ("<run-id> or --job required
# when not running interactively"), so the id must be resolved first.
def "work-pr _do-rerun" [st: record, dry: bool]: nothing -> int {
    let id = (work-pr _run-id $st)
    if ($id | is-empty) {
        print -e $"no Actions run found for ($st.headRefOid) — rerun from the browser"
        return 1
    }
    if $dry { print $"[dry-run] gh run rerun ($id) --repo ($st.repo) --failed"; return 0 }
    let r = (do { ^gh run rerun $id --repo $st.repo --failed } | complete)
    if $r.exit_code != 0 { print -e $"rerun failed: ($r.stderr | str trim)"; return 1 }
    print $"♻️ rerunning failed jobs of run ($id)"
    0
}

# --fail-fast WITHOUT --watch is a hard error, so always emit both. Exit 8 means
# "checks pending", which is not a failure of the watch action; exit 1 covers
# both "a check failed" and "no checks reported", so never read CI state from it.
def "work-pr _do-watch" [st: record, dry: bool]: nothing -> int {
    if $dry { print $"[dry-run] gh pr checks ($st.num) --repo ($st.repo) --watch --fail-fast"; return 0 }
    let r = (do { ^gh pr checks $st.num --repo $st.repo --watch --fail-fast } | complete)
    print $r.stdout
    if $r.exit_code == 8 { print -e "checks still pending"; return 0 }
    if $r.exit_code != 0 {
        print -e $"checks not green \(exit ($r.exit_code)\): ($r.stderr | str trim)"
        return 0
    }
    0
}

# Commits and PUSHES, so the repo check comes first and runs on --dry-run too.
def "work-pr _do-kick" [st: record, yes: bool, dry: bool]: nothing -> int {
    let loc = (work-pr _try-local-worktree $st "kick CI" $"kick needs ($st.headRefName) checked out somewhere in ($st.repo) — pick 🌱/👓 worktree first")
    if $loc == null { return 1 }
    if $dry {
        print $"[dry-run] git -C ($loc.worktree) commit --allow-empty -m 'chore: kick CI'; git push"
        return 0
    }
    if not (work-pr _confirm $"kick CI on ($st.headRefName) — empty commit + push from ($loc.worktree)?" $yes) {
        print -e "kick skipped"
        return 0
    }
    let c = (do { ^git -C $loc.worktree commit --allow-empty -m "chore: kick CI" } | complete)
    if $c.exit_code != 0 { print -e $"empty commit failed: ($c.stderr | str trim)"; return 1 }
    let p = (do { ^git -C $loc.worktree push } | complete)
    if $p.exit_code != 0 { print -e $"push failed: ($p.stderr | str trim)"; return 1 }
    print $"🦵 kicked CI on ($st.headRefName)"
    0
}

# ── stack — thin `gh stack` passthrough ──────────────────────────────────────
# `gh stack` has NO -R/--repo on any subcommand and ignores GH_REPO, so every row
# runs inside the real checkout. v0.1.0 preview: each row is one line so that
# when the extension moves, one row breaks instead of half the tool.
def "work-pr _stack-rows" []: nothing -> list<record> {
    [
        {id: "stack:view",   glyph: "🧱", label: "view stack"}
        {id: "stack:add",    glyph: "🥞", label: "new branch on top of this PR (starts a stack if needed)"}
        {id: "stack:submit", glyph: "📤", label: "submit stack (--auto)"}
        {id: "stack:sync",   glyph: "🔄", label: "sync stack (fetch + cascade rebase + atomic push)"}
        {id: "stack:rebase", glyph: "♻️", label: "rebase stack"}
        {id: "stack:merge",  glyph: "🚀", label: "merge stack up to this PR"}
    ]
}

def "work-pr _do-stack" [st: record, id: string, yes: bool, dry: bool]: nothing -> int {
    if (which gh | is-empty) { print -e "gh not found on PATH"; return 1 }
    # Strip the prefix BEFORE the guard: the `what` slot already says "gh stack", so
    # passing the raw row id reads `gh stack stack:view needs a local checkout`.
    let sub = ($id | str replace "stack:" "")
    let loc = (work-pr _try-local-worktree $st $"gh stack ($sub)" "gh stack has no --repo flag — pick a worktree first")
    if $loc == null { return 1 }
    if $dry { print $"[dry-run] cd ($loc.worktree); gh stack ($sub)"; return 0 }
    cd $loc.worktree
    if $sub == "view" {
        let r = (do { ^gh stack view } | complete)
        print $r.stdout
        # `gh stack view` exits 2 when the branch is not part of a stack, writing
        # to stderr with stdout empty. gh documents 2 as "command cancelled", so a
        # generic `exit_code == 2 → cancelled` check misreads "no stack here".
        if $r.exit_code == 2 { print "not part of a stack"; return 0 }
        if $r.exit_code != 0 { print -e ($r.stderr | str trim); return 1 }
        return 0
    }
    if $sub == "add" {
        if not (is-terminal --stdin) { print -e "stack:add needs a TTY to name the new branch"; return 1 }
        let name = (input "new branch on top: " | str trim)
        if ($name | is-empty) { print -e "no branch name"; return 0 }
        # `gh stack checkout <pr>` only works for a PR that is ALREADY in a stack, so
        # for a lone PR — the common case, since this row is how a stack gets started
        # — fall back to `gh stack init <head>`, which turns the existing branch into
        # a one-entry stack. Without this the row is unusable exactly when it is most
        # wanted, and there is deliberately no separate `stack:init` row to pick.
        let co = (do { ^gh stack checkout $st.num } | complete)
        if $co.exit_code != 0 {
            let init = (do { ^gh stack init $st.headRefName } | complete)
            if $init.exit_code != 0 {
                print -e $"gh stack checkout failed: ($co.stderr | str trim)"
                print -e $"gh stack init ($st.headRefName) also failed: ($init.stderr | str trim)"
                return 1
            }
            print $"🧱 started a stack at ($st.headRefName)"
        }
        let a = (do { ^gh stack add $name } | complete)
        if $a.exit_code != 0 { print -e $"gh stack add failed: ($a.stderr | str trim)"; return 1 }
        print $"🥞 ($name) added on top of #($st.num)"
        return 0
    }
    if $sub == "submit" {
        let r = (do { ^gh stack submit --auto } | complete)
        print $r.stdout
        if $r.exit_code != 0 { print -e $"gh stack submit failed: ($r.stderr | str trim)"; return 1 }
        return 0
    }
    if $sub == "sync" {
        if not (work-pr _confirm $"sync the whole stack from ($loc.worktree) — cascade rebase + force-with-lease push?" $yes) {
            print -e "sync skipped"
            return 0
        }
        let r = (do { ^gh stack sync } | complete)
        print $r.stdout
        if $r.exit_code != 0 { print -e $"gh stack sync failed: ($r.stderr | str trim)"; return 1 }
        return 0
    }
    if $sub == "rebase" {
        let r = (do { ^gh stack rebase } | complete)
        print $r.stdout
        if $r.exit_code != 0 { print -e $"gh stack rebase failed: ($r.stderr | str trim)"; return 1 }
        return 0
    }
    if $sub == "merge" {
        # Accepts a stack-number or a PR-number and merges every member UP TO AND
        # INCLUDING that PR atomically, so pass the PR number explicitly.
        if not (work-pr _confirm $"merge the stack up to and including #($st.num) — all-or-nothing?" $yes) {
            print -e "stack merge skipped"
            return 0
        }
        let r = (do { ^gh stack merge $st.num --yes } | complete)
        print $r.stdout
        if $r.exit_code != 0 { print -e $"gh stack merge failed: ($r.stderr | str trim)"; return 1 }
        return 0
    }
    print -e $"unknown stack action: ($id)"
    1
}

# Sub-picker over the stack rows; `--action stack:<sub>` skips it.
def "work-pr _do-stack-pick" [st: record, yes: bool, dry: bool]: nothing -> int {
    let rows = (work-pr _stack-rows)
    # Before the picker, same reason as _do-trim: the sub-picker needs a TTY, and a
    # headless --dry-run must describe the plan instead of dying on the guard.
    if $dry {
        print $"[dry-run] stack sub-picker for #($st.num): (($rows | get id | str join ', '))"
        return 0
    }
    let keys = (work-pr _fzf ($rows | each {|r| $"($r.id)\t($r.glyph)  ($r.label)" }) "stack> " $"($st.repo) #($st.num) — gh stack v0.1.0 \(preview)")
    if ($keys | is-empty) { return 0 }
    mut f = 0
    for k in $keys { $f += (work-pr _do-stack $st $k $yes $dry) }
    $f
}

# ── worktree + agent launch ──────────────────────────────────────────────────

# Lift of work.nu's old `work pr` body, minus the layout call. Returns
# {path, workspace_id, created}.
def "work-pr _worktree" [st: record, mode: string, focus: bool]: nothing -> record {
    work deps-preflight
    # Was `work repo-info` with no repo check, so a gh-dash `T` on a foreign PR
    # built the worktree inside whatever repo the shell sat in.
    let loc = (work-pr _require-local $st "worktree/agent intents")
    let parent = $loc.root
    let head = $st.headRefName
    if ($head | is-empty) { work-pr _die $"PR #($st.num) has no head branch." }
    # Same value `work repo-info` reports as `name` — the parent root's basename.
    let repo_name = ($parent | path basename)
    let wt_path = (work worktree-path $repo_name $head)
    let label = (work _label $repo_name $head)
    let focus_flag = (if $focus { "--focus" } else { "--no-focus" })

    let existing_co = $loc.worktree
    if ($existing_co | is-not-empty) {
        print -e $"Worktree for PR #($st.num) exists, opening."
        let r = (do { ^herdr worktree open --cwd $parent --path $existing_co --label $label $focus_flag --json } | complete)
        let ws = (try { $r.stdout | from json | get -o result.workspace.workspace_id } catch { "" })
        return {path: $existing_co, workspace_id: $ws, created: false}
    }

    if $st.isCrossRepository {
        # Fork: git creates the detached checkout + gh sets up the fork remote,
        # then herdr opens it.
        let a = (do { ^git -C $parent worktree add --detach $wt_path } | complete)
        if $a.exit_code != 0 { work-pr _die $"worktree add failed: ($a.stderr | str trim)" }
        let co = (do { ^bash -c $"cd '($wt_path)' && gh pr checkout ($st.num)" } | complete)
        if $co.exit_code != 0 {
            # Rollback is load-bearing: an orphan detached worktree at the
            # canonical path blocks the next attempt.
            ^git -C $parent worktree remove $wt_path --force
            work-pr _die $"gh pr checkout #($st.num) failed: ($co.stderr | str trim)"
        }
        let cur = (do { ^git -C $wt_path branch --show-current } | complete | get stdout | str trim)
        if ($cur | is-empty) { ^git -C $wt_path checkout -B $head | ignore }
        do { ^herdr worktree open --cwd $parent --path $wt_path --label $label $focus_flag --json } | complete | ignore
    } else {
        # Same-repo: herdr creates the checkout tracking the PR branch.
        do { ^git -C $parent fetch origin $head } | complete | ignore
        let r = (do { ^herdr worktree create --cwd $parent --branch $head --base $"origin/($head)" --path $wt_path --label $label $focus_flag --json } | complete)
        if $r.exit_code != 0 { work-pr _die $"herdr worktree create failed: ($r.stderr | str trim)" }
    }

    if $mode == "full" { work _seed-untracked $parent $wt_path }
    {path: $wt_path, workspace_id: (work _herdr-ws-for $parent $wt_path), created: true}
}

def "work-pr _do-worktree" [st: record, mode: string, focus: bool, dry: bool]: nothing -> int {
    if $dry { print $"[dry-run] worktree \(($mode)\) for #($st.num) → ($st.headRefName)"; return 0 }
    let r = (work-pr _worktree $st $mode $focus)
    work _apply-layout $r.workspace_id $r.path
    print -e $"✅ PR #($st.num) → ($st.headRefName)"
    0
}

# The pre-layout side effects, replicated so the agent path never calls
# `work _apply-layout` — that def returns early when a tab labelled "claude"
# already exists AND auto-launches a bare `claude` when none does, so calling it
# here would either drop the brief silently or start two sessions.
def "work-pr _agent-prep" [ws: string, cwd: path]: nothing -> nothing {
    if (which place-work-skills | is-not-empty) { do { ^place-work-skills $cwd } | complete | ignore }
    if (which claude-mcp-defaults | is-not-empty) { do { ^claude-mcp-defaults $cwd } | complete | ignore }
    if ($ws | is-empty) { return }
    let tabs = (try { (do { ^herdr tab list --workspace $ws } | complete).stdout | from json | get -o result.tabs | default [] } catch { [] })
    for t in $tabs {
        if (($t.label? | default "") =~ '^[0-9]+$') {
            do { ^herdr tab rename $t.tab_id $"\u{f120}  nu" } | complete | ignore
        }
    }
}

# Always a FRESH tab. `herdr pane run` joins COMMAND… with spaces and TYPES the
# line into whatever owns the pane, so reusing a tab that already runs claude
# would send the line to claude's prompt box as literal text. The label contains
# "claude", so a later `work _apply-layout` still suppresses its own bare launch.
def "work-pr _agent-tab" [ws: string, cwd: path, intent: string, cmd: string]: nothing -> int {
    let r = (do { ^herdr tab create --workspace $ws --cwd $cwd --label $"\u{f06a9}  claude ($intent)" --no-focus } | complete)
    let pane = (try { $r.stdout | from json | get -o result.root_pane.pane_id } catch { "" })
    if ($pane | is-empty) { print -e $"herdr tab create returned no pane: ($r.stderr | str trim)"; return 1 }
    do { ^herdr pane run $pane $cmd } | complete | ignore
    0
}

# Cache path for a PR's brief. Keyed on repo AND number: PR #5 exists in every
# repo, so a number-only name makes two repos overwrite each other's brief and the
# agent gets handed the wrong PR's context.
def "work-pr _brief-path" [st: record]: nothing -> path {
    let slug = ($st.repo | str replace -a "/" "-")
    $nu.home-dir | path join ".cache" $"pr-brief-($slug)-($st.num).md"
}

# Brief file for one PR — pr-brief's stdout, cached so the pane only needs a path.
def "work-pr _brief" [st: record, intent: string]: nothing -> string {
    let out = (work-pr _brief-path $st)
    # --repo is mandatory, not best-effort: pr-brief's own `work-repo` resolves
    # WORK_MAIN_REPO and ignores cwd, so without it a dotfiles or home-lab PR gets
    # briefed against the SAME NUMBER in the work monorepo. Fail loudly instead.
    let r = (do { ^pr-brief $st.num --repo $st.repo --intent $intent } | complete)
    if $r.exit_code != 0 { print -e $"pr-brief failed: ($r.stderr | str trim)"; return "" }
    mkdir ($out | path dirname)
    $r.stdout | save -f $out
    # Fire-and-forget launch: if the file is missing, `open --raw` fails inside
    # the pane's nushell and nothing surfaces here.
    if not ($out | path exists) { print -e $"brief not written to ($out)"; return "" }
    $out
}

def "work-pr _do-agent" [st: record, intent: string, mode: string, focus: bool, dry: bool]: nothing -> int {
    if $dry {
        print $"[dry-run] pr-brief ($st.num) --repo ($st.repo) --intent ($intent) → (work-pr _brief-path $st), then a fresh claude tab \(worktree: ($mode)\)"
        return 0
    }
    if $mode == "none" {
        # No worktree (bump): target the current herdr workspace, or hand the line
        # over for a manual paste.
        let out = (work-pr _brief $st $intent)
        if ($out | is-empty) { return 1 }
        let cmd = $"claude \(open --raw \"($out)\")"
        let ws = ($env.HERDR_WORKSPACE_ID? | default "")
        if ($ws | is-empty) {
            print $cmd
            return 0
        }
        return (work-pr _agent-tab $ws $env.PWD $intent $cmd)
    }
    let wt = (work-pr _worktree $st $mode $focus)
    work-pr _agent-prep $wt.workspace_id $wt.path
    let out = (work-pr _brief $st $intent)
    if ($out | is-empty) { return 1 }
    # ONE argv element of nushell syntax. `pane run` joins argv with spaces, so
    # `bash -lc 'claude "$(cat F)"'` would arrive as `bash -lc claude "$(cat F)"`
    # and bash would get only `claude` as its -c string.
    let cmd = $"claude \(open --raw \"($out)\")"
    let rc = (work-pr _agent-tab $wt.workspace_id $wt.path $intent $cmd)
    print -e $"✅ PR #($st.num) → ($st.headRefName) · claude ($intent)"
    $rc
}

# ── registry ────────────────────────────────────────────────────────────────
# A `const` cannot hold a closure, so this is a def returning a list of records.
# Contract:
#   id        machine key — hidden fzf field 1, and the --action value
#   group     "agent" | "worktree" | "gh"     (dispatch order: gh → worktree → agent)
#   kind      optional; "label" marks a row whose id IS a repo label name. The
#             pre-write validation reads this, so a 4th label row is picked up by
#             adding the field — never by editing a second hardcoded id list.
#   glyph     display only
#   label     display only
#   glyph_of  optional {|st| string} — overrides glyph
#   label_of  optional {|st| string} — overrides label
#   state     optional {|st| string} — inline annotation in parentheses
#   relevant  {|st| bool}  — drives the relevance partition
#   run       {|st, ctx| int} — returns a failure count
# ctx = {yes, dry, focus, labels, drop}
def "work-pr registry" []: nothing -> list<record> {
    [
        {
            id: "resolve" group: "gh" glyph: "✅" label: "resolve all conversations"
            state: {|st| $"((work-pr _unresolved-n $st))(if $st.threads_truncated { '+' } else { '' }) unresolved" }
            relevant: {|st| (work-pr _unresolved-n $st) > 0 }
            run: {|st, ctx| work-pr _do-resolve $st $ctx.dry }
        }
        {
            id: "review" group: "agent" glyph: "👀" label: "review this PR"
            relevant: {|st| not $st.isMine }
            run: {|st, ctx| work-pr _do-agent $st "review" "light" $ctx.focus $ctx.dry }
        }
        {
            id: "respond" group: "agent" glyph: "💬" label: "answer reviewers"
            state: {|st| $"((work-pr _unresolved-n $st)) unresolved" }
            relevant: {|st| $st.isMine and ((work-pr _unresolved-n $st) > 0) }
            run: {|st, ctx| work-pr _do-agent $st "respond" "full" $ctx.focus $ctx.dry }
        }
        {
            id: "fix-ci" group: "agent" glyph: "🔧" label: "fix failing CI"
            state: {|st| $"($st.failed) red" }
            relevant: {|st| $st.isMine and ($st.failed > 0) }
            run: {|st, ctx| work-pr _do-agent $st "fix-ci" "full" $ctx.focus $ctx.dry }
        }
        {
            id: "babysit" group: "agent" glyph: "🤖" label: "autonomous pass"
            relevant: {|st| $st.isMine and (($st.failed > 0) or ($st.mergeable == "CONFLICTING")) }
            run: {|st, ctx| work-pr _do-agent $st "babysit" "full" $ctx.focus $ctx.dry }
        }
        {
            # No reviewRequestedAt in `gh pr view --json`, so "> 2 days" cannot be
            # computed yet — the row exists so `--action bump` works and a later
            # timelineItems query can promote it.
            id: "bump" group: "agent" glyph: "📣" label: "nudge reviewers on Slack"
            relevant: {|st| false }
            run: {|st, ctx| work-pr _do-agent $st "bump" "none" $ctx.focus $ctx.dry }
        }
        {
            id: "logs" group: "gh" glyph: "🔍" label: "tail failed check logs"
            state: {|st| $"($st.failed) red" }
            relevant: {|st| $st.failed > 0 }
            run: {|st, ctx| work-pr _do-logs $st $ctx.dry }
        }
        {
            id: "rerun" group: "gh" glyph: "♻️" label: "rerun failed checks"
            relevant: {|st| $st.failed > 0 }
            run: {|st, ctx| work-pr _do-rerun $st $ctx.dry }
        }
        {
            id: "re-review" group: "gh" glyph: "🔔" label: "re-request review (changes requested)"
            relevant: {|st| $st.reviewDecision == "CHANGES_REQUESTED" }
            run: {|st, ctx| work-pr _do-re-review $st $ctx.dry }
        }
        {
            id: "trim" group: "gh" glyph: "✂️" label: "trim requested reviewers"
            state: {|st| $"($st.reviewRequests | length) requested" }
            relevant: {|st| ($st.reviewRequests | length) > 1 }
            run: {|st, ctx| work-pr _do-trim $st $ctx.drop $ctx.dry }
        }
        {
            id: "no-changeset-needed" group: "gh" kind: "label" glyph: "🏷" label: "toggle no-changeset-needed"
            state: {|st| if ("no-changeset-needed" in $st.labels) { "on" } else { "off" } }
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-label $st "no-changeset-needed" $ctx.labels $ctx.dry }
        }
        {
            id: "run_e2e" group: "gh" kind: "label" glyph: "🏷" label: "toggle run_e2e"
            state: {|st| if ("run_e2e" in $st.labels) { "on" } else { "off" } }
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-label $st "run_e2e" $ctx.labels $ctx.dry }
        }
        {
            id: "skip_e2e" group: "gh" kind: "label" glyph: "🏷" label: "toggle skip_e2e"
            state: {|st| if ("skip_e2e" in $st.labels) { "on" } else { "off" } }
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-label $st "skip_e2e" $ctx.labels $ctx.dry }
        }
        {
            id: "kick" group: "gh" glyph: "🦵" label: "kick CI (empty commit + push)"
            relevant: {|st| $st.checks_total == 0 }
            run: {|st, ctx| work-pr _do-kick $st $ctx.yes $ctx.dry }
        }
        {
            id: "watch" group: "gh" glyph: "👁" label: "watch checks"
            state: {|st| $"($st.pending) pending" }
            relevant: {|st| $st.pending > 0 }
            run: {|st, ctx| work-pr _do-watch $st $ctx.dry }
        }
        {
            id: "update-merge" group: "gh" glyph: "⬆️" label: "update branch from base (merge commit)"
            relevant: {|st| $st.mergeStateStatus == "BEHIND" }
            run: {|st, ctx| work-pr _do-update-branch $st false $ctx.yes $ctx.dry }
        }
        {
            id: "update-rebase" group: "gh" glyph: "⬆️" label: "update branch from base (rebase, force-push)"
            relevant: {|st| $st.mergeStateStatus == "BEHIND" }
            run: {|st, ctx| work-pr _do-update-branch $st true $ctx.yes $ctx.dry }
        }
        {
            id: "merge" group: "gh" glyph: "🚀" label: "merge --squash --auto"
            relevant: {|st| $st.isMine and (not $st.isDraft) }
            run: {|st, ctx| work-pr _do-merge $st $ctx.yes $ctx.dry }
        }
        {
            id: "ready" group: "gh" glyph: "📤" label: "ready for review"
            glyph_of: {|st| if $st.isDraft { "📤" } else { "📥" } }
            label_of: {|st| if $st.isDraft { "ready for review" } else { "back to draft" } }
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-ready $st $ctx.dry }
        }
        {
            id: "blockers" group: "gh" glyph: "🚧" label: "merge blockers report"
            state: {|st| $st.mergeStateStatus }
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-blockers $st }
        }
        {
            id: "stack" group: "gh" glyph: "🥞" label: "stack…"
            state: {|st| if ($st.stack == null) { "" } else { $"($st.stack.position)/($st.stack.size) of stack #($st.stack.number)" } }
            # Real membership, from `PullRequest.stack` (see `work-pr _stack`): null =
            # this PR is not in a stack (or the read was skipped/unsupported), so the
            # row sorts cold and is still pickable — that is how a stack gets STARTED
            # via stack:add, which falls back to `gh stack init` for a lone PR.
            # Stacks require every branch in one repository, so forks are excluded.
            relevant: {|st| ($st.stack != null) and (not $st.isCrossRepository) }
            run: {|st, ctx| work-pr _do-stack-pick $st $ctx.yes $ctx.dry }
        }
        {
            id: "wt-full" group: "worktree" glyph: "🌱" label: "full worktree (seed .env + node_modules)"
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-worktree $st "full" $ctx.focus $ctx.dry }
        }
        {
            id: "wt-light" group: "worktree" glyph: "👓" label: "light worktree (no seed)"
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-worktree $st "light" $ctx.focus $ctx.dry }
        }
        {
            id: "diff" group: "worktree" glyph: "📄" label: "diff only → pager"
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-diff $st $ctx.dry }
        }
        {
            id: "web" group: "gh" glyph: "🌐" label: "open in browser"
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-web $st $ctx.dry }
        }
        {
            id: "copy" group: "gh" glyph: "📋" label: "copy URL"
            relevant: {|st| true }
            run: {|st, ctx| work-pr _do-copy $st $ctx.dry }
        }
    ]
}

# ── picker ──────────────────────────────────────────────────────────────────

# `default` EVALUATES a closure argument as a lazy default, so never use it to
# supply a fallback closure — guard on the column instead.
def "work-pr _annotate" [reg: list<record>, st: record]: nothing -> list<record> {
    $reg
    | insert rel {|it| do $it.relevant $st }
    | insert ann {|it| if ("state" in ($it | columns)) { do $it.state $st } else { "" } }
    | insert disp_glyph {|it| if ("glyph_of" in ($it | columns)) { do $it.glyph_of $st } else { $it.glyph } }
    | insert disp_label {|it| if ("label_of" in ($it | columns)) { do $it.label_of $st } else { $it.label } }
}

# The row format is a CONTRACT, not cosmetics: machine key in a hidden first
# field, a REAL tab as the delimiter (nushell double quotes produce one — the
# two-character sequence `\t` would be read by fzf as a regex escape), and
# `--with-nth "2.."` to hide field 1. Drop any of the three and either the key
# leaks into the display or an emoji/count tweak breaks the parse.
# fzf, not Television — tv's filter quality is too weak.
def "work-pr _fzf" [rows: list<string>, prompt: string, header: string]: nothing -> list<string> {
    if ($rows | is-empty) { return [] }
    # `complete` cannot catch a missing binary — nushell raises before it runs.
    if (which fzf | is-empty) { work-pr _die "fzf not found on PATH — pass --action instead" }
    # Sub-pickers are reachable from --action (trim without --drop, bare `stack`),
    # which the dispatcher's TTY guard does not cover. fzf would block forever on
    # /dev/tty in a headless caller, so refuse instead of hanging.
    if not (is-terminal --stdin) {
        work-pr _die "this picker needs a TTY — pass --drop / --action stack:<sub> instead"
    }
    let r = (do {
        $rows | str join "\n" | ^fzf --multi --delimiter "\t" --with-nth "2.." --reverse --prompt $prompt --header $header
    } | complete)
    # 130 = Esc/Ctrl-C, 1 = no match; both mean "nothing selected". Anything else
    # is a broken picker, which must not be mistaken for a cancel.
    if $r.exit_code in [1 130] { return [] }
    if $r.exit_code != 0 { work-pr _die $"fzf failed \(($r.exit_code)\): ($r.stderr | str trim)" }
    $r.stdout | lines | where {|l| ($l | str trim) != ""} | each {|l| $l | split row "\t" | first }
}

# Ordered registry ids the current state calls for — the picker's top section.
# Composite on purpose (every applicable next step, not a single verdict): the
# same signals as `work-pr action` / `_do-blockers`, in unblock-the-merge order.
# Promotion overrides `relevant`: the update-* rows are only `rel` on BEHIND,
# but a CONFLICTING PR must still surface them on top.
def "work-pr _suggest" [st: record]: nothing -> list<string> {
    mut out = []
    if (work-pr _unresolved-n $st) > 0 {
        $out = ($out | append "resolve")
        if $st.isMine { $out = ($out | append "respond") }
    }
    if $st.failed > 0 {
        if $st.isMine { $out = ($out | append "fix-ci") }
        $out = ($out | append ["logs" "rerun"])
    }
    if $st.mergeable == "CONFLICTING" {
        $out = ($out | append ["update-merge" "update-rebase"])
    } else if $st.mergeStateStatus == "BEHIND" {
        $out = ($out | append "update-merge")
    }
    if ($st.e2e_expected > 0) and ($st.e2e_running == 0) { $out = ($out | append "run_e2e") }
    if $st.pending > 0 { $out = ($out | append "watch") }
    if $st.reviewDecision == "CHANGES_REQUESTED" { $out = ($out | append "re-review") }
    if $st.isDraft { $out = ($out | append "ready") }
    # The classifier already gates MERGE on green checks + no unresolved; isMine
    # mirrors the merge row's own `relevant`.
    if (($st | get -o action | default "") == "MERGE") and $st.isMine and (not $st.isDraft) {
        $out = ($out | append "merge")
    }
    $out | uniq
}

# Relevance PARTITION, not sort-by: `sort-by rel --reverse` reorders within each
# group, which shuffles the registry order the rows were written in. Suggested
# rows go first, in `_suggest`'s order — fzf's cursor starts on row 1, so a bare
# Enter does the right thing for the PR's current state.
def "work-pr _pick" [st: record, reg: list<record>]: nothing -> list<string> {
    let a = (work-pr _annotate $reg $st)
    let sug = (work-pr _suggest $st)
    # each-over-sug, not `where id in $sug`: keeps _suggest's order, not the
    # registry's.
    let sug_rows = ($sug | each {|id| $a | where id == $id } | flatten)
    let rest = ($a | where {|it| not ($it.id in $sug)})
    let hot = ($rest | where rel)
    let cold = ($rest | where {|it| not $it.rel})
    let ordered = ($sug_rows | append $hot | append $cold)
    let rows = ($ordered | each {|it|
        let mark = (if ($it.id in $sug) { "→ " } else if $it.rel { "" } else { "· " })
        let suffix = (if ($it.ann | is-empty) { "" } else { $" \(($it.ann)\)" })
        $"($it.id)\t($mark)($it.disp_glyph)  ($it.disp_label | fill -w 34)($suffix)"
    })
    let header = $"($st.repo) #($st.num) — ($st.title | str substring 0..60) · TAB for multiple"
    work-pr _fzf $rows "pr> " $header
}

# ── dispatcher ──────────────────────────────────────────────────────────────

# One pass over a picked id set: split registry/stack/label ids, validate labels
# BEFORE the first write, order the plan (gh → labels → stack → worktree → at
# most one agent), run it. `took_over` is true when an agent/worktree action ran
# — focus already moved to another workspace, so the menu loop must not reclaim
# this screen with a fresh picker.
def "work-pr _dispatch" [st: record, ids: list<string>, reg: list<record>, ctx: record]: nothing -> record {
    let known_ids = ($reg | get id)
    # `stack:<sub>` reaches _do-stack directly; anything else unknown is treated
    # as a literal label name (pr-menu compatibility).
    let stack_ids = ($ids | where {|i| $i | str starts-with "stack:"})
    let reg_ids = ($ids | where {|i| $i in $known_ids})
    let label_ids = ($ids | where {|i| (not ($i in $known_ids)) and (not ($i | str starts-with "stack:"))})

    # `resolve` stays a RESERVED id: never a label alias, excluded from label
    # validation, dispatched on its id. A repo label literally named `resolve`
    # therefore cannot be toggled here.
    #
    # Which registry rows are label toggles comes from the registry itself
    # (`kind: "label"`), not from a second list that a 4th label row would silently
    # skip — skipping it means skipping the validate-before-first-write guard that
    # stops a TAB multi-select from half-applying.
    let label_rows = ($reg | where {|r| ($r | get -o kind | default "") == "label"} | get id)
    let wanted = (($reg_ids | where {|i| $i in $label_rows}) | append $label_ids)
    work-pr _validate-labels $st.repo $wanted

    # gh actions first (registry order), then worktree, then AT MOST ONE agent —
    # the agent takes over the terminal, so it runs last.
    let gh_ids = ($reg | where group == "gh" | get id | where {|i| $i in $reg_ids})
    let wt_ids = ($reg | where group == "worktree" | get id | where {|i| $i in $reg_ids})
    let ag_all = ($reg | where group == "agent" | get id | where {|i| $i in $reg_ids})
    let ag_ids = (
        if ($ag_all | length) > 1 {
            print -e $"more than one agent intent selected — running (($ag_all | first)), skipping the rest"
            [($ag_all | first)]
        } else { $ag_all }
    )
    # A worktree row alongside an agent row means TWO claude sessions in the same
    # tree: the worktree row goes through `work _apply-layout`, which auto-launches
    # a bare `claude`, and the agent row then opens its own briefed tab. The agent
    # row already creates the tree, so the worktree row is redundant — drop it and
    # say so rather than spawning a second session nobody asked for.
    let wt_kept = (
        if ($ag_ids | is-not-empty) and ($wt_ids | is-not-empty) {
            print -e $"($ag_ids | first) already creates the worktree — skipping ($wt_ids | str join ', ')"
            []
        } else { $wt_ids }
    )
    let plan = ($gh_ids | append $label_ids | append $stack_ids | append $wt_kept | append $ag_ids)

    mut failures = 0
    mut results = []
    for id in $plan {
        let row = ($reg | where id == $id)
        let f = (
            if ($row | is-empty) {
                if ($id | str starts-with "stack:") {
                    work-pr _do-stack $st $id $ctx.yes $ctx.dry
                } else {
                    work-pr _do-label $st $id $ctx.labels $ctx.dry
                }
            } else {
                let r0 = ($row | first)
                do $r0.run $st $ctx
            }
        )
        let n = (if ($f | describe) == "int" { $f } else { 0 })
        $failures += $n
        $results = ($results | append {id: $id, failures: $n})
    }
    {
        failures: $failures
        results: $results
        took_over: (($ag_ids | is-not-empty) or ($wt_kept | is-not-empty))
    }
}

# `--action` accepts, in this order: a registry id, a `stack:<sub>` passthrough, an
# alias from WORKPR_LABEL_ALIASES, or — pr-menu compatibility — a literal repo
# label name.
#
# That last door is what made a typo dangerous: anything unrecognised used to fall
# straight through to `_do-label`, so `--action mrege` reported a MISSING LABEL
# instead of a bad action, and in a repo that happens to carry a label of that name
# the toggle actually FIRED. So the door only opens for a name the repo really has:
# `gh label list` is the disambiguator, and it is the authority on what is a label.
# Not a registry id, not `stack:*`, not a real label ⇒ bad action, said plainly.
def "work-pr _resolve-action" [act: string, repo: string, known_ids: list<string>]: nothing -> string {
    if $act in $known_ids { return $act }
    if ($act | str starts-with "stack:") { return $act }
    let aliased = ($WORKPR_LABEL_ALIASES | get -o $act | default $act)
    if $aliased in $known_ids { return $aliased }
    # One extra `gh label list` on this rare compat path; `_validate-labels` still
    # runs before the write, since it is what keeps a TAB batch from half-applying.
    if $aliased in (work-pr _repo-labels $repo) { return $aliased }
    work-pr _die ([
        $"unknown --action '($act)' — not a registry id, not a label in ($repo)"
        $"  actions : (($known_ids | str join ', '))"
        $"  aliases : (($WORKPR_LABEL_ALIASES | columns | str join ', '))"
        $"  stack   : ((work-pr _stack-rows | get id | str join ', '))"
    ] | str join (char newline))
}

def "work pr" [
    number?: int              # PR number (positional wins over --pr)
    --pr: int = 0             # 0 = not given
    --repo: string = ""       # owner/name; "" = gh cwd detection
    --action: string = ""     # registry id | label alias | literal label; required with no TTY
    --drop: string = ""       # comma-separated reviewer slugs/logins for --action trim
    --yes                     # skip confirmations
    --json                    # pr-state + per-action results as the LAST stdout line
    --dry-run                 # print each action's plan, no mutating call
    --pause                   # hold the screen before returning (gh-dash)
    --no-focus
    --no-seed                 # back-compat: with no --action, means wt-light
    --full                    # back-compat: with no --action, means wt-full
]: nothing -> any {
    # FIRST statement, before every guard: nested defs read this env var, so a
    # --pause passed as a parameter would lose the hold on every die reached from
    # a helper and gh-dash would repaint over the message — invisible errors.
    $env.WORK_PR_PAUSE = (if $pause { "1" } else { "0" })
    if (which gh | is-empty) { work-pr _die "gh not found on PATH" }

    let pr_flag = (if ($number | is-not-empty) { $number } else { $pr })
    let act = (
        if ($action | is-not-empty) { $action }
        else if $full { "wt-full" }
        else if $no_seed { "wt-light" }
        else { "" }
    )
    if ($act | is-empty) and (not (is-terminal --stdin)) {
        work-pr _die "work pr needs a TTY for the picker; pass --action instead"
    }

    let target = (work-pr _resolve-menu-target $repo $pr_flag)
    # `--repo foo --pr 5` dies here; `--repo foo` (no --pr) hits the different die
    # inside _resolve-target first, because _cwd-repo runs before this check.
    let parts = ($target.repo | split row "/")
    if ($parts | length) != 2 { work-pr _die $"--repo must be owner/name, got '($target.repo)'" }
    # 0 = the PR picker was cancelled.
    if $target.num == 0 { return }

    let reg = (work-pr registry)
    let known_ids = ($reg | get id)
    # Resolve --action BEFORE any PR read: a typo should cost one error line, not a
    # wasted `gh pr view` and certainly not a label write.
    let act_id = (if ($act | is-not-empty) { work-pr _resolve-action $act $target.repo $known_ids } else { "" })

    # Skip the reads a path does not need: a pure label action never touches
    # GraphQL. One round trip shared by the menu count and the mutation set.
    let needs_threads = (($act_id | is-empty) or ($act_id in ["resolve" "respond" "blockers"]))
    mut st = (
        if $needs_threads {
            work-pr _state $target.repo $target.num
        } else {
            work-pr _state $target.repo $target.num --no-threads
        }
    )

    mut failures = 0
    mut results = []
    if ($act_id | is-not-empty) {
        # Headless/back-compat path: exactly one pass, no loop — gh-dash `T`,
        # scripts and `--json` consumers keep today's behaviour.
        let ctx = {yes: $yes, dry: $dry_run, focus: (not $no_focus), labels: $st.labels, drop: $drop}
        let d = (work-pr _dispatch $st [$act_id] $reg $ctx)
        $failures = $d.failures
        $results = $d.results
    } else {
        # Menu loop: run the picked actions, refetch, offer the menu again — one
        # PR usually needs several. Esc/Ctrl-C leaves; so does an agent/worktree
        # action, because focus already moved to another workspace.
        loop {
            let ids = (work-pr _pick $st $reg)
            if ($ids | is-empty) { break }
            # ctx is rebuilt per iteration: the `labels` snapshot must track what
            # the previous pass just toggled.
            let ctx = {yes: $yes, dry: $dry_run, focus: (not $no_focus), labels: $st.labels, drop: $drop}
            let d = (work-pr _dispatch $st $ids $reg $ctx)
            $failures += $d.failures
            $results = ($results | append $d.results)
            if $d.took_over { break }
            # Full refetch, threads included — the counters, annotations and
            # suggestion order have to reflect what the actions just changed.
            $st = (work-pr _state $st.repo $st.num)
        }
        # Cancel with nothing run deliberately does NOT hold the screen and emits
        # no JSON (mirrors pr-menu's exit 0 — the pre-loop behaviour).
        if ($results | is-empty) { return }
    }

    # --json BEFORE --pause: the hold blocks on `input`, and a caller that asked for
    # JSON cannot supply a keypress, so holding first deadlocks it out of its output.
    if $json {
        # Never serialize a registry row: `to json` on a closure raises
        # nu::shell::unsupported_input and that abort is not catchable.
        print ({state: ($st | reject unresolved_threads), results: $results} | to json -r)
    }
    # Always hold BEFORE the failure raise, so gh-dash users see the text.
    if $pause { work-pr _hold }
    if $failures > 0 {
        error make --unspanned {msg: $"work pr: ($failures) action\(s) failed"}
    }
}
