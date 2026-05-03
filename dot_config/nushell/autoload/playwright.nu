# Playwright helpers

# Find nearest Playwright project directory
def find-playwright-dir [] {
  let start = (pwd)
  mut dir = $start

  loop {
    if (($dir | path join "playwright.config.ts") | path exists) or (($dir | path join "playwright.config.js") | path exists) {
      return $dir
    }

    let reunite_dir = ($dir | path join "e2e" "reunite")
    if (($reunite_dir | path join "playwright.config.ts") | path exists) {
      return $reunite_dir
    }

    let parent = ($dir | path dirname)
    if $parent == $dir {
      return $start
    }
    $dir = $parent
  }
}

# Build a Playwright test command
def build-playwright-command [
  target: string
  title?: string
  --project: string
  --headed
  --debug
] {
  let base = ["pnpm" "exec" "playwright" "test"]
  let with_project = if ($project | is-empty) { $base } else { $base | append [$"--project=($project)"] }
  let with_headed = if $headed { $with_project | append ["--headed"] } else { $with_project }
  let with_debug = if $debug { $with_headed | append ["--debug"] } else { $with_headed }
  let with_target = $with_debug | append $target

  if ($title | is-empty) {
    $with_target
  } else {
    $with_target | append ["-g" $title]
  }
}

# Infer the Playwright project for a selected target
def infer-playwright-project [
  target: string
  --project: string
] {
  if not ($project | is-empty) {
    return $project
  }

  if ($target | str starts-with "tests/auth") {
    "Authentication tests"
  } else {
    ""
  }
}

# Render a command so arguments with spaces are copy-pasteable
def display-command [command: list<string>] {
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

# Completion values for Playwright specs and tests
def "nu-complete-playwright-targets" [] {
  try {
    bash $"($env.HOME)/.config/television/cable/playwright-tests-source.sh"
    | lines
    | each { |line|
        let parts = ($line | split row "\t")
        let kind = ($parts | get 0)
        let file = ($parts | get 1)

        if $kind == "test" {
          let title = ($parts | get 2)
          {
            value: $"test ($file) ($title)",
            description: $"test: ($title)"
          }
        } else {
          {
            value: $file,
            description: "spec file"
          }
        }
      }
  } catch {
    []
  }
}

# Convert Television or Nushell completion selection to file and optional test title
def parse-playwright-selection [selection: list<string>] {
  let first = ($selection | get 0)

  if $first == "test" {
    {
      target: ($selection | get 1),
      title: ($selection | skip 2 | str join " ")
    }
  } else if $first == "spec" or $first == "path" {
    {
      target: ($selection | get 1),
      title: null
    }
  } else {
    {
      target: $first,
      title: (if (($selection | length) > 1) { $selection | skip 1 | str join " " } else { null })
    }
  }
}

# Pick and run a Playwright spec, directory, or single test with Television
export def pwt [
  ...selection: string@"nu-complete-playwright-targets" # Optional spec, directory, or test selection. If omitted, opens Television picker.
  --project(-p): string # Override Playwright project. Auth tests are detected automatically.
  --headed             # Show the browser while the test runs.
  --debug              # Open Playwright Inspector and run in debug mode.
] {
  let pwdir = (find-playwright-dir)
  let raw_selection = if ($selection | is-empty) {
    tv playwright-tests | str trim
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
  let parsed = (parse-playwright-selection $parts)
  let inferred_project = (infer-playwright-project $parsed.target --project $project)
  let command = (build-playwright-command $parsed.target $parsed.title --project $inferred_project --headed=$headed --debug=$debug)

  print $"cd ($pwdir)"
  print (display-command $command)

  cd $pwdir
  ^($command | get 0) ...($command | skip 1)
}
