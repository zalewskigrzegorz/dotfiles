#!/usr/bin/env nu
# Tests for bin/pr-watch-alerts.nu. Run: nu scripts/test-pr-watch-alerts.nu
use std/assert

const ALERTS_NU = (path self "../bin/pr-watch-alerts.nu")
source $ALERTS_NU

const NOW = "2026-10-20T13:42:00+02:00"

def snap [--failed: list<string> = [], --pending, --approvers: list<string> = [], --out: int = 0] {
    {failed: $failed, failed_urls: ($failed | reduce -f {} {|n, acc| $acc | insert $n $"https://github.com/o/r/actions/runs/1/job/($n | str length)"}), pending: $pending, approvers: $approvers, outstanding: $out}
}

def test_no_baseline [] {
    assert equal (pr-alert diff {} {"1": (snap --failed ["e2e (3)"])} $NOW) {}
    assert equal (pr-alert diff {"1": {outstanding: 0}} {"1": (snap --failed ["e2e (3)"])} $NOW) {}
}

def test_new_fail [] {
    let ev = (pr-alert diff {"7": (snap)} {"7": (snap --failed ["e2e (3)"])} $NOW | get "7")
    assert equal $ev.kind "ci_fail"
    assert equal $ev.text "e2e (3)"
    assert equal $ev.num 7
    assert equal $ev.url "https://github.com/o/r/actions/runs/1/job/7"
    assert equal $ev.ts $NOW
}

def test_second_shard [] {
    let ev = (pr-alert diff {"7": (snap --failed ["e2e (1)"])} {"7": (snap --failed ["e2e (1)" "e2e (3)"])} $NOW | get "7")
    assert equal $ev.kind "ci_fail"
    assert equal $ev.text "e2e (3)"
}

def test_ci_start [] {
    let ev = (pr-alert diff {"7": (snap)} {"7": (snap --pending)} $NOW | get "7")
    assert equal $ev.kind "ci_start"
    assert equal $ev.text ""
}

def test_approval_and_comment_same_poll [] {
    let d = (pr-alert diff {"7": (snap)} {"7": (snap --approvers ["kasia"] --out 2)} $NOW)
    assert equal ($d | columns | length) 1
    assert equal $d."7".kind "approval"
    assert equal $d."7".text "kasia"
}

def test_comment [] {
    let ev = (pr-alert diff {"7": (snap --out 1)} {"7": (snap --out 2)} $NOW | get "7")
    assert equal $ev.kind "comment"
    assert equal $ev.text ""
}

def test_closed_pr [] {
    assert equal (pr-alert diff {"7": (snap)} {} $NOW) {}
}

def test_merge_priority [] {
    let fail = {ts: "2026-10-20T13:00:00+02:00", num: 7, kind: "ci_fail", text: "e2e padł", url: "u"}
    let start = {ts: $NOW, num: 7, kind: "ci_start", text: "CI ruszyło", url: "u"}
    assert equal (pr-alert merge {"7": $fail} {"7": $start})."7".kind "ci_fail"
    let c1 = {ts: "2026-10-20T13:00:00+02:00", num: 7, kind: "comment", text: "komentarz", url: "u"}
    let c2 = ($c1 | upsert ts $NOW)
    assert equal (pr-alert merge {"7": $c1} {"7": $c2})."7".ts $NOW
    let other = ($start | upsert num 8)
    assert equal (pr-alert merge {"7": $fail} {"8": $other} | columns | sort) ["7" "8"]
}

def test_sound [] {
    let evs = {"7": {kind: "comment"}, "8": {kind: "ci_fail"}}
    assert equal (pr-alert sound $evs) "ci_fail"
    assert equal (pr-alert sound {}) ""
}

def test_snapshot [] {
    let pr = {
        statusCheckRollup: [
            {__typename: "CheckRun", name: "e2e (3)", status: "COMPLETED", conclusion: "FAILURE", detailsUrl: "https://github.com/x/1"}
            {__typename: "CheckRun", name: "build", status: "IN_PROGRESS", conclusion: "", detailsUrl: "https://github.com/x/2"}
            {__typename: "StatusContext", context: "ci/legacy", state: "ERROR", targetUrl: "https://github.com/x/3"}
        ]
        latestReviews: [
            {author: {login: "kasia"}, state: "APPROVED"}
            {author: {login: "bot"}, state: "COMMENTED"}
        ]
    }
    let s = (pr-alert snapshot $pr 3)
    assert equal $s.failed ["e2e (3)" "ci/legacy"]
    assert equal ($s.failed_urls | get "ci/legacy") "https://github.com/x/3"
    assert equal $s.pending true
    assert equal $s.approvers ["kasia"]
    assert equal $s.outstanding 3
}

def main [] {
    let tests = [
        [name, run];
        [no_baseline, {|| test_no_baseline }]
        [new_fail, {|| test_new_fail }]
        [second_shard, {|| test_second_shard }]
        [ci_start, {|| test_ci_start }]
        [approval_and_comment_same_poll, {|| test_approval_and_comment_same_poll }]
        [comment, {|| test_comment }]
        [closed_pr, {|| test_closed_pr }]
        [merge_priority, {|| test_merge_priority }]
        [sound, {|| test_sound }]
        [snapshot, {|| test_snapshot }]
    ]
    for t in $tests {
        do $t.run
        print $"ok ($t.name)"
    }
}
