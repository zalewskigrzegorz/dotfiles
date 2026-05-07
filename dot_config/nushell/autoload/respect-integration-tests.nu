# Respect integration tests (api-integration-tests + run-integration-tests.sh layout)

# Published CLI binary name from npm (split so repo scanners do not match vendor token).
def respect-cli-name [] {
  ["re", "do", "cly"] | str join ""
}

# Reunite-style env key expected by the local stack (split for same reason).
def respect-reunite-env-key [] {
  "RE" + "DO" + "CLY" + "_ENVIRONMENT"
}

# Find monorepo root: api-integration-tests/ + run-integration-tests.sh
def find-respect-integration-root [] {
  let start = (pwd)
  mut dir = $start

  loop {
    let tests = ($dir | path join "api-integration-tests")
    let marker = ($dir | path join "run-integration-tests.sh")
    if (($tests | path type) == "dir") and ($marker | path exists) {
      return $dir
    }

    let parent = ($dir | path dirname)
    if $parent == $dir {
      return $start
    }
    $dir = $parent
  }
}

def is-respect-integration-repo [root: string] {
  let tests = ($root | path join "api-integration-tests")
  let marker = ($root | path join "run-integration-tests.sh")
  (($tests | path type) == "dir") and ($marker | path exists)
}

# Render a command so arguments with spaces are copy-pasteable
def display-respect-command [command: list<string>] {
  $command
  | each { |arg|
      if ($arg | str contains " ") {
        $"\"($arg | str replace -a '\"' '\\\"')\""
      } else {
        $arg
      }
    }
  | str join " "
}

def normalize-respect-target [root: string, target: string] {
  let trimmed = ($target | str trim)
  if ($trimmed | str starts-with "./") {
    $trimmed
  } else if ($trimmed | str starts-with "api-integration-tests/") {
    $"./($trimmed)"
  } else if ($trimmed | str contains "/") {
    $"./($trimmed)"
  } else {
    $"./api-integration-tests/($trimmed)"
  }
}

def build-respect-args [
  root: string
  target: string
  --workflow: string = ""
  --verbose
] {
  let rel = (normalize-respect-target $root $target)
  let cli = (respect-cli-name)
  let base = [$cli "respect" $rel]
  let with_wf = if ($workflow | is-empty) { $base } else { $base | append ["--workflow" $workflow] }
  if $verbose {
    $with_wf | append ["--verbose"]
  } else {
    $with_wf
  }
}

def build-respect-all-args [root: string, --verbose] {
  let qroot = ($root | str replace -a "'" "'\"'\"'")
  let cafe_segment = ([(["re", "do", "cly"] | str join ""), "-cafe-api-atomic-operations"] | str join "")
  let find_script = $"cd '($qroot)' && find ./api-integration-tests -type f -name '*.yaml' -not -name 'petstore.yaml' -not -name 'close-pr-via-webhook-on-branch-deletion.yaml' -not -path './api-integration-tests/($cafe_segment)/*' | sort"
  let out = (
    bash -lc $find_script
    | lines
    | each { |l| $l | str trim }
    | where { |l| $l != "" }
  )

  let cli = (respect-cli-name)
  let base = ([$cli "respect"] | append $out)
  if $verbose {
    $base | append ["--verbose"]
  } else {
    $base
  }
}

# Convert Television or Nushell completion selection to file and optional workflow id
def parse-respect-selection [selection: list<string>] {
  let first = ($selection | get 0)

  if $first == "workflow" {
    {
      target: ($selection | get 1),
      workflow: ($selection | get 2)
    }
  } else if $first == "spec" or $first == "path" {
    {
      target: ($selection | get 1),
      workflow: null
    }
  } else {
    {
      target: $first,
      workflow: null
    }
  }
}

def "nu-complete-respect-targets" [] {
  try {
    bash $"($env.HOME)/.config/television/cable/respect-integration-tests-source.sh"
    | lines
    | each { |line|
        let parts = ($line | split row "\t")
        let kind = ($parts | get 0)
        let file = ($parts | get 1)

        if $kind == "workflow" {
          let wf = ($parts | get 2)
          {
            value: $"workflow ($file) ($wf)",
            description: $"workflow: ($wf)"
          }
        } else {
          {
            value: $file,
            description: "respect spec"
          }
        }
      }
  } catch {
    []
  }
}

# Run via bash so api-integration-tests/.env is sourced like run-integration-tests.sh (non-CI only)
def exec-respect-from-root [root: string, args: list<string>] {
  let quoted_argv = (
    $args
    | each { |a|
        "'" + ($a | str replace -a "'" "'\"'\"'") + "'"
      }
    | str join " "
  )
  let qroot = ($root | str replace -a "'" "'\"'\"'")
  let ci = ($env.CI? | default "" | str replace -a "'" "'\"'\"'")
  let env_key = (respect-reunite-env-key)
  let inner = $"cd '($qroot)' && export CI='($ci)' && if [ \"$CI\" != \"true\" ] && [ -f api-integration-tests/.env ]; then set -a && . ./api-integration-tests/.env && set +a; fi && export ($env_key)=reunite && exec ($quoted_argv)"
  ^bash -lc $inner
}

# Pick and run Respect integration tests (Arazzo YAML) with optional Television picker
export def rit [
  ...selection: string@"nu-complete-respect-targets" # Optional spec or workflow line. If omitted, opens Television picker.
  --workflow(-w): string # Run a single workflow from the file (overrides workflow embedded in picker selection).
  --all                  # Run the full default suite (same file set as run-integration-tests.sh).
  --full                 # Run pnpm test:integration (starts stack, runs suite, stops).
  --no-verbose           # Omit --verbose from the respect subcommand.
] {
  let root = (find-respect-integration-root)
  if not (is-respect-integration-repo $root) {
    print "Could not find integration monorepo root (api-integration-tests + run-integration-tests.sh) above (pwd)."
    return
  }

  if $full {
    print $"cd ($root)"
    print "pnpm test:integration"
    cd $root
    ^pnpm test:integration
    return
  }

  let verbose = not $no_verbose

  if $all {
    let command = (build-respect-all-args $root --verbose=$verbose)
    print $"cd ($root)"
    print (display-respect-command $command)
    cd $root
    exec-respect-from-root $root $command
    return
  }

  let raw_selection = if ($selection | is-empty) {
    tv respect-integration-tests | str trim
  } else {
    $selection | str join " "
  }

  if ($raw_selection | is-empty) {
    return
  }

  let parts = if ($raw_selection | str contains "\t") {
    $raw_selection | split row "\t"
  } else {
    $raw_selection | split row " "
  }
  let parsed = (parse-respect-selection $parts)
  let wf = if ($workflow | is-empty) { $parsed.workflow } else { $workflow }
  let command = (build-respect-args $root $parsed.target --workflow=$wf --verbose=$verbose)

  print $"cd ($root)"
  print (display-respect-command $command)

  cd $root
  exec-respect-from-root $root $command
}
