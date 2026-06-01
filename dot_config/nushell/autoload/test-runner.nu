# test-runner.nu — discoverable namespace over ut / rit / pwt
#
# `test`              — pick a kind interactively, then delegate
# `test unit  ...`    → ut  (unit tests, vitest/jest)
# `test e2e   ...`    → pwt (playwright E2E)
# `test integ ...`    → rit (respect integration tests)
# `test help`         — print the mapping
#
# All extra args/flags after the kind are forwarded verbatim to the
# underlying runner via list spread, so e.g. `test unit -w foo.spec.ts`
# behaves exactly like `ut -w foo.spec.ts`.

def "nu-complete-test-kinds" [] {
  [
    { value: "unit",  description: "ut  — unit tests (vitest / jest)" }
    { value: "e2e",   description: "pwt — playwright E2E" }
    { value: "integ", description: "rit — respect integration tests" }
    { value: "help",  description: "show the mapping" }
  ]
}

def print-test-help [] {
  print "test <kind> [...args] — dispatches to:"
  print "  test unit  → ut   (run `ut --help`  for flags)"
  print "  test e2e   → pwt  (run `pwt --help` for flags)"
  print "  test integ → rit  (run `rit --help` for flags)"
  print ""
  print "Bare `test` opens a picker for the kind, then the runner's own picker."
}

def pick-test-kind [] {
  ["unit" "e2e" "integ"] | input list "test kind:"
}

export def --wrapped test [
  kind?: string@"nu-complete-test-kinds" # unit | e2e | integ | help — omit to pick interactively
  ...rest: string                         # forwarded verbatim to the underlying runner
] {
  let chosen = if ($kind | is-empty) { pick-test-kind } else { $kind }
  if ($chosen | is-empty) { return }

  match $chosen {
    "unit"  => { ut  ...$rest }
    "e2e"   => { pwt ...$rest }
    "integ" => { rit ...$rest }
    "help"  => { print-test-help }
    _ => {
      print $"unknown test kind: ($chosen). expected: unit | e2e | integ | help"
    }
  }
}
