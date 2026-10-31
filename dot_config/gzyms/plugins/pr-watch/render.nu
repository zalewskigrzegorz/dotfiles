# PR watch for Gzyms: turns bin/pr-watch's cache files into protocol lines.
#   nu render.nu        → notify lines for events not told yet, then the pill with its list
#   nu render.nu seen   → the list was opened: queued events become "shown" (bin/pr-watch-open did this on click)
# Same rows, tags and colours as the SketchyBar popup (scriptc/pr-watch-open.ts).

const CACHE = ($nu.home-dir | path join ".cache" "pr-watch-last.json")
const CHIP = ($nu.home-dir | path join ".cache" "pr-watch-chip.json")
const ALERTS = ($nu.home-dir | path join ".cache" "pr-watch-alerts.json")
const SHOWN = ($nu.home-dir | path join ".cache" "pr-watch-alerts-shown.json")
const TOLD = ($nu.home-dir | path join ".cache" "gzyms-pr-watch-told.json")
const KIND_ORDER = [ci_fail approval ci_success comment ci_start]

def read-json [p: string, empty: any]: nothing -> any {
    if not ($p | path exists) { return $empty }
    try { open $p } catch { $empty }
}

# The SketchyBar tag and colour per action, colours as Gzyms theme tokens.
def tag-for [action: string]: nothing -> record {
    match $action {
        "fix CI" => {tag: "fix CI", color: "peach"}
        "changes req" => {tag: "changes!", color: "peach"}
        "run e2e" => {tag: "run e2e!", color: "peach"}
        "conflict" => {tag: "conflict", color: "red"}
        "resolve" => {tag: "resolve", color: "sky"}
        "CI…" => {tag: "CI runs…", color: "gold"}
        "MERGE" => {tag: "merge ✓", color: "green"}
        "draft+CI" => {tag: "draft+CI", color: "pink"}
        "draft" => {tag: "draft", color: "mauve"}
        "needs review" => {tag: "review?", color: "lavender"}
        "blocked" => {tag: "blocked", color: "lavender"}
        _ => {tag: $action, color: "overlay"}
    }
}

def event-row [ev: record, prs: record]: nothing -> record {
    let key = ($ev.key? | default ($ev.num? | default 0 | into string))
    let pr = ($prs | get -o $key | default {})
    let t = ($ev.text? | default "")
    let what = match ($ev.kind? | default "") {
        "ci_fail" => (if $t == "" { "CI failed" } else { $"CI failed: ($t)" })
        "approval" => (if $t == "" { "approved" } else { $"approved by ($t)" })
        "ci_success" => "CI green"
        "comment" => "new comment"
        "ci_start" => "CI started"
        _ => $t
    }
    let style = match ($ev.kind? | default "") {
        "ci_fail" => {tag: "✗ CI", color: "red"}
        "approval" => {tag: "👍 review", color: "green"}
        "ci_success" => {tag: "✓ CI", color: "green"}
        "comment" => {tag: "💬 new", color: "sky"}
        "ci_start" => {tag: "▶ CI", color: "gold"}
        _ => {tag: "•", color: "overlay"}
    }
    {
        id: $"ev:($key)", tag: $style.tag, color: $style.color,
        text: $"($pr.repo_short? | default '')#($ev.num? | default '?')  ($what)  ($pr.title? | default '')",
        detail: ($ev.ts? | default "" | str substring 11..15)
    }
}

def events [path: string]: nothing -> list<record> {
    read-json $path {} | values | sort-by {|e| $KIND_ORDER | enumerate | where item == ($e.kind? | default "") | get -o 0.index | default 9 }
}

def main [mode: string = "render"] {
    if $mode == "seen" {
        # what bin/pr-watch-open did on a click: show this batch, empty the queue
        read-json $ALERTS {} | to json | save -f $SHOWN
        {} | to json | save -f $ALERTS
        return
    }

    let prs = (read-json $CACHE {})
    let queued = (events $ALERTS)

    # Tell new events once, as Gzyms notifications. bin/pr-watch already plays its own sound, so none here.
    let told = (read-json $TOLD null)
    let keys = ($queued | each {|e| $"($e.key? | default ($e.num? | default 0))/($e.kind? | default '')/($e.ts? | default '')" })
    if $told != null {
        for e in ($queued | zip $keys | where {|p| $p.1 not-in $told } | each {|p| $p.0 }) {
            let r = (event-row $e $prs)
            let pr = ($prs | get -o ($e.key? | default "") | default {})
            print ({notify: {id: $r.id, title: ($r.text | str replace -r '  .*$' '' | $"($in)  ($r.tag)"),
                body: ($r.text | split row "  " | skip 1 | str join "  "), link: ($e.url? | default ($pr.url? | default "")),
                level: (if $e.kind? == "ci_fail" { "warning" } else { "info" })}} | to json -r)
        }
    }
    $keys | to json | save -f $TOLD

    # The pill: the chip's counts; an unseen event alone keeps it up with a bell (as the SketchyBar chip did).
    let c = (read-json $CHIP {})
    mut parts = []
    if ($c.fix? | default 0) > 0 { $parts = ($parts | append $"✗ ($c.fix)") }
    if ($c.merge? | default 0) > 0 { $parts = ($parts | append $"✓ ($c.merge)") }
    if ($c.comments? | default 0) > 0 { $parts = ($parts | append $"💬 ($c.comments)") }
    if ($c.run? | default 0) > 0 { $parts = ($parts | append $"⏳ ($c.run)") }
    if ($parts | is-empty) and ($queued | is-not-empty) { $parts = ["🔔"] }
    if ($parts | is-empty) {
        print ({item: {id: "prs", remove: true}} | to json -r)
        return
    }
    let color = (if ($c.fix? | default 0) > 0 { "peach" } else if ($c.comments? | default 0) > 0 { "sky" } else if ($c.run? | default 0) > 0 { "gold" } else { "green" })

    # The list: events (queued, then already shown), a line, then every PR, actionable first, newest on top.
    let ev_rows = ($queued | append (events $SHOWN) | each {|e| event-row $e $prs })
    let pr_rows = ($prs | transpose key e
        | sort-by -r {|r| [(if ($r.e.actionable? | default false) { 1 } else { 0 }), ($r.e.num? | default 0)] }
        | each {|r|
            let t = (tag-for ($r.e.action? | default ""))
            let n = ($r.e.outstanding? | default 0)
            {id: $"pr:($r.key)", tag: $t.tag, color: $t.color,
             text: $"($r.e.repo_short? | default '')#($r.e.num? | default '?')  ($r.e.title? | default '')",
             detail: (if $n > 0 { $"💬 ($n)" } else { "" })}
        })
    mut menu = $ev_rows
    if ($ev_rows | is-not-empty) { $menu = ($menu | append {separator: true}) }
    $menu = ($menu | append (if ($pr_rows | is-empty) { [{text: "No data yet, wait for the next pr-watch poll"}] } else { $pr_rows }))

    print ({item: {id: "prs", text: ($parts | str join " "), icon: "arrow.triangle.pull", color: $color,
        tooltip: "Click: your PRs · right click: gh-dash", menu: $menu}} | to json -r)
}
