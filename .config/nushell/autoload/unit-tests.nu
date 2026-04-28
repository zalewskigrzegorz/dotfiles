# Unit test helpers

# Find the nearest unit-test project directory from anywhere inside a workspace.
def find-unit-test-dir [] {
  let start = (pwd)
  mut dir = $start

  loop {
    let nested_test_dir = ($dir | path join "apps" "api")
    if (has-test-runner $nested_test_dir) {
      return $nested_test_dir
    }

    if (has-test-runner $dir) {
      return $dir
    }

    let parent = ($dir | path dirname)
    if $parent == $dir {
      return $start
    }
    $dir = $parent
  }
}

def has-test-runner [dir: string] {
  (($dir | path join "package.json") | path exists) and (
    (($dir | path join "vitest.config.ts") | path exists)
    or (($dir | path join "vitest.config.js") | path exists)
    or (($dir | path join "jest.config.ts") | path exists)
    or (($dir | path join "jest.config.js") | path exists)
  )
}

def detect-test-runner [dir: string] {
  if (($dir | path join "jest.config.ts") | path exists) or (($dir | path join "jest.config.js") | path exists) {
    "jest"
  } else {
    "vitest"
  }
}

def has-package-script [dir: string, script: string] {
  let package_json = ($dir | path join "package.json")
  if not ($package_json | path exists) {
    return false
  }

  let scripts = (open $package_json | get --optional scripts)
  if ($scripts == null) {
    return false
  }

  $script in ($scripts | columns)
}

# Render a command so arguments with spaces are copy-pasteable.
def display-unit-test-command [command: list<string>] {
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

# Normalize targets selected from a workspace root or from the test project.
def normalize-unit-test-target [target: string] {
  if ($target | str starts-with "apps/api/") {
    $target | str replace "apps/api/" ""
  } else {
    $target
  }
}

# Build a test command for a directory, spec file, or single test.
def build-unit-test-command [
  runner: string
  target?: string
  title?: string
  --watch
  --coverage
  --update
] {
  let base = if $runner == "jest" {
    if $watch {
      ["pnpm" "exec" "jest" "--watch"]
    } else if $coverage {
      ["pnpm" "exec" "jest" "--coverage"]
    } else {
      ["pnpm" "exec" "jest"]
    }
  } else {
    if $watch {
      ["pnpm" "exec" "vitest"]
    } else if $coverage {
      ["pnpm" "exec" "vitest" "run" "--passWithNoTests" "--coverage"]
    } else {
      ["pnpm" "exec" "vitest" "run" "--passWithNoTests"]
    }
  }

  let with_update = if $update { $base | append ["--update"] } else { $base }
  let with_target = if ($target | is-empty) { $with_update } else { $with_update | append (normalize-unit-test-target $target) }

  if ($title | is-empty) {
    $with_target
  } else if $runner == "jest" {
    $with_target | append ["--testNamePattern" $title]
  } else {
    $with_target | append ["-t" $title]
  }
}

# Convert Television or Nushell completion selection to file and optional test title.
def parse-unit-test-selection [selection: list<string>] {
  let first = ($selection | get 0)

  if $first == "test" {
    {
      target: ($selection | get 1),
      title: ($selection | skip 2 | str join " ")
    }
  } else if $first == "spec" or $first == "dir" or $first == "path" {
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

# Pick and run a unit test directory, spec, or single scenario with Television.
export def ut [
  ...selection: string # Optional directory, spec, or test selection. If omitted, opens Television picker.
  --title(-t): string                                # Override or provide a test-name pattern.
  --watch(-w)                                        # Run the test runner in watch mode.
  --coverage(-c)                                     # Run with coverage.
  --update(-u)                                       # Update snapshots.
] {
  let test_dir = (find-unit-test-dir)
  let raw_selection = if ($selection | is-empty) {
    tv unit-tests | str trim
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
  let parsed = (parse-unit-test-selection $parts)
  let test_title = if ($title | is-empty) { $parsed.title } else { $title }
  let runner = (detect-test-runner $test_dir)
  let command = (build-unit-test-command $runner $parsed.target $test_title --watch=$watch --coverage=$coverage --update=$update)
  let prepare_command = if (has-package-script $test_dir "prepare-mocks") {
    "pnpm run prepare-mocks && "
  } else {
    ""
  }

  print $"cd ($test_dir)"
  print $"($prepare_command)(display-unit-test-command $command)"

  cd $test_dir
  if (has-package-script $test_dir "prepare-mocks") {
    ^pnpm run prepare-mocks
    if $env.LAST_EXIT_CODE != 0 {
      return
    }
  }
  ^($command | get 0) ...($command | skip 1)
}
