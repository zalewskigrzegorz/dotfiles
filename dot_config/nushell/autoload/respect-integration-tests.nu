# Respect integration tests (api-integration-tests + run-integration-tests.sh layout)

def respect-cli-name [] {
  let cli = ($env.WORK_MAIN_PROJECT? | default "")
  if ($cli | is-empty) {
    error make { msg: "WORK_MAIN_PROJECT is not set. Run chezmoi apply/sync so private Nushell env is rendered." }
  }
  $cli
}

def respect-cli-package [] {
  "@" + (respect-cli-name) + "/cli"
}

def respect-reunite-env-key [] {
  ((respect-cli-name) | str uppercase) + "_ENVIRONMENT"
}

def default-respect-debug-dir [] {
  "/tmp/respect-debug"
}

def default-respect-har-output [] {
  default-respect-debug-dir | path join "latest.har"
}

def default-respect-json-output [] {
  default-respect-debug-dir | path join "latest.json"
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
  --har-output: string = ""
  --json-output: string = ""
  --no-secrets-masking
  --max-fetch-timeout: int = 0
  --execution-timeout: int = 0
] {
  let rel = (normalize-respect-target $root $target)
  let cli = (respect-cli-name)
  let pkg = (respect-cli-package)
  let base = ["pnpm" $"--package=($pkg)" "dlx" $cli "respect" $rel]
  let with_wf = if ($workflow | is-empty) { $base } else { $base | append ["--workflow" $workflow] }
  let with_verbose = if $verbose {
    $with_wf | append ["--verbose"]
  } else {
    $with_wf
  }
  append-respect-diagnostic-args $with_verbose --har-output=$har_output --json-output=$json_output --no-secrets-masking=$no_secrets_masking --max-fetch-timeout=$max_fetch_timeout --execution-timeout=$execution_timeout
}

def append-respect-diagnostic-args [
  command: list<string>
  --har-output: string = ""
  --json-output: string = ""
  --no-secrets-masking
  --max-fetch-timeout: int = 0
  --execution-timeout: int = 0
] {
  let with_har = if ($har_output | is-empty) { $command } else { $command | append ["--har-output" $har_output] }
  let with_json = if ($json_output | is-empty) { $with_har } else { $with_har | append ["--json-output" $json_output] }
  let with_masking = if $no_secrets_masking { $with_json | append ["--no-secrets-masking"] } else { $with_json }
  let with_fetch_timeout = if $max_fetch_timeout > 0 { $with_masking | append ["--max-fetch-timeout" ($max_fetch_timeout | into string)] } else { $with_masking }
  if $execution_timeout > 0 {
    $with_fetch_timeout | append ["--execution-timeout" ($execution_timeout | into string)]
  } else {
    $with_fetch_timeout
  }
}

def normalize-diagnostic-output-path [root: string, output_path: string] {
  if ($output_path | is-empty) {
    ""
  } else if ($output_path | str starts-with "/") {
    $output_path
  } else {
    $root | path join $output_path
  }
}

def ensure-diagnostic-output-parent [output_path: string] {
  if not ($output_path | is-empty) {
    let parent = ($output_path | path dirname)
    if not ($parent | path exists) {
      mkdir $parent
    }
  }
}

def build-respect-all-args [
  root: string
  --verbose
  --har-output: string = ""
  --json-output: string = ""
  --no-secrets-masking
  --max-fetch-timeout: int = 0
  --execution-timeout: int = 0
] {
  let qroot = ($root | str replace -a "'" "'\"'\"'")
  let cafe_segment = ([(respect-cli-name), "-cafe-api-atomic-operations"] | str join "")
  let find_script = $"cd '($qroot)' && find ./api-integration-tests -type f -name '*.yaml' -not -name 'petstore.yaml' -not -name 'close-pr-via-webhook-on-branch-deletion.yaml' -not -path './api-integration-tests/($cafe_segment)/*' | sort"
  let out = (
    bash -lc $find_script
    | lines
    | each { |l| $l | str trim }
    | where { |l| $l != "" }
  )

  let cli = (respect-cli-name)
  let pkg = (respect-cli-package)
  let base = (["pnpm" $"--package=($pkg)" "dlx" $cli "respect"] | append $out)
  let with_verbose = if $verbose {
    $base | append ["--verbose"]
  } else {
    $base
  }
  append-respect-diagnostic-args $with_verbose --har-output=$har_output --json-output=$json_output --no-secrets-masking=$no_secrets_masking --max-fetch-timeout=$max_fetch_timeout --execution-timeout=$execution_timeout
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
  --workflow(-w): string = "" # Run a single workflow from the file (overrides workflow embedded in picker selection).
  --all                  # Run the full default suite (same file set as run-integration-tests.sh).
  --full                 # Run pnpm test:integration (starts stack, runs suite, stops).
  --debug(-d)            # Write HAR + JSON debug artifacts to /tmp/respect-debug and use local debug-friendly flags.
  --no-verbose           # Omit --verbose from the respect subcommand.
  --har-output(-H): string = "" # Write a HAR file for request-level debugging.
  --json-output(-J): string = "" # Write a JSON result file.
  --no-har               # Do not write the default HAR file.
  --no-secrets-masking   # Show unmasked secrets in output; use only locally.
  --max-fetch-timeout: int = 0 # Override per-request timeout in milliseconds.
  --execution-timeout: int = 0 # Override total execution timeout in milliseconds.
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
  let effective_har_output = if not ($har_output | is-empty) {
    normalize-diagnostic-output-path $root $har_output
  } else if $debug and (not $no_har) {
    default-respect-har-output
  } else {
    ""
  }
  let effective_json_output = if not ($json_output | is-empty) {
    normalize-diagnostic-output-path $root $json_output
  } else if $debug {
    default-respect-json-output
  } else {
    ""
  }
  let effective_no_secrets_masking = $no_secrets_masking or $debug
  let effective_max_fetch_timeout = if $max_fetch_timeout > 0 { $max_fetch_timeout } else if $debug { 120000 } else { 0 }
  let effective_execution_timeout = if $execution_timeout > 0 { $execution_timeout } else if $debug { 7200000 } else { 0 }

  ensure-diagnostic-output-parent $effective_har_output
  ensure-diagnostic-output-parent $effective_json_output

  if $all {
    let command = (build-respect-all-args $root --verbose=$verbose --har-output=$effective_har_output --json-output=$effective_json_output --no-secrets-masking=$effective_no_secrets_masking --max-fetch-timeout=$effective_max_fetch_timeout --execution-timeout=$effective_execution_timeout)
    print $"cd ($root)"
    if $debug {
      print $"Diagnostic output dir: (default-respect-debug-dir)"
    }
    if not ($effective_har_output | is-empty) {
      print $"HAR output: ($effective_har_output)"
    }
    if not ($effective_json_output | is-empty) {
      print $"JSON output: ($effective_json_output)"
    }
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
  let command = (build-respect-args $root $parsed.target --workflow=$wf --verbose=$verbose --har-output=$effective_har_output --json-output=$effective_json_output --no-secrets-masking=$effective_no_secrets_masking --max-fetch-timeout=$effective_max_fetch_timeout --execution-timeout=$effective_execution_timeout)

  print $"cd ($root)"
  if $debug {
    print $"Diagnostic output dir: (default-respect-debug-dir)"
  }
  if not ($effective_har_output | is-empty) {
    print $"HAR output: ($effective_har_output)"
  }
  if not ($effective_json_output | is-empty) {
    print $"JSON output: ($effective_json_output)"
  }
  print (display-respect-command $command)

  cd $root
  exec-respect-from-root $root $command
}
