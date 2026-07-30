# Verify built type artifacts across a pnpm workspace.
#
# Catches the failures that leave a package looking built while its types are
# gone, so a broken artifact never gets cached or published:
#   - a declaration entrypoint that does not exist
#   - the entrypoint re-exporting a file missing from the output dir
#   - a raw .ts next to its emitted .d.ts (TypeScript may resolve the source)
#   - a nested duplicate copy dir (generated/generated) from a bad cp -r
#   - for prisma packages, a missing PrismaJson namespace or annotated type
#
# Output dirs come from the manifest (types, main, exports), so lib/ and
# bundle/ are checked the same way as dist/. Packages whose output dir does not
# exist are treated as not built and skipped.

def workspace-root [start: string] {
  mut dir = ($start | path expand)
  loop {
    if (($dir | path join "pnpm-workspace.yaml") | path exists) { return $dir }
    let parent = ($dir | path dirname)
    if $parent == $dir { return ($start | path expand) }
    $dir = $parent
  }
}

def read-text [file: string] {
  open --raw $file | decode utf-8
}

def manifest-targets [manifest: record] {
  let direct = [
    ($manifest | get -o types)
    ($manifest | get -o typings)
    ($manifest | get -o main)
    ($manifest | get -o module)
  ]
  let exported = (
    $manifest
    | get -o exports
    | default {}
    | values
    | each {|entry| if ($entry | describe | str starts-with "record") { $entry | values } else { [$entry] } }
    | flatten
  )
  $direct | append $exported | compact | where {|target| ($target | describe) == "string" } | uniq
}

def output-roots [dir: string, manifest: record] {
  manifest-targets $manifest
  | each {|target| $target | str replace -r '^\./' '' | path split | get -o 0 }
  | compact
  | where {|root| $root != ".." and (($dir | path join $root | path type) == "dir") }
  | uniq
}

def declaration-entry [dir: string, manifest: record] {
  let types = ($manifest | get -o types | default ($manifest | get -o typings))
  if $types == null { return null }
  $dir | path join $types
}

def declaration-candidates [target: string] {
  if ($target | str ends-with ".d.ts") { return [$target] }
  if ($target | str ends-with ".ts") {
    return [$target, ($target | str replace -r '\.ts$' '.d.ts')]
  }
  let js = ($target | parse -r '\.(?<ext>m?c?js)$' | get -o 0.ext)
  if $js != null {
    let base = ($target | str replace -r '\.m?c?js$' '')
    let mapped = match $js {
      "mjs" => [$"($base).d.mts"]
      "cjs" => [$"($base).d.cts"]
      _ => []
    }
    return ($mapped | append [$"($base).d.ts", $target])
  }
  [
    $"($target).d.ts"
    $"($target).d.mts"
    $"($target).d.cts"
    $"($target).ts"
    ($target | path join "index.d.ts")
  ]
}

def resolve-specifier [base_dir: string, package_dir: string, spec: string] {
  let target = ($base_dir | path join $spec | path expand)
  if not ($target | str starts-with $package_dir) { return "outside" }
  declaration-candidates $target | where {|candidate| ($candidate | path exists) } | get -o 0
}

def reexport-specifiers [entry: string] {
  read-text $entry
  | parse -r `from\s+['"](?<spec>[^'"]+)['"]`
  | get spec
  | where {|spec| ($spec | str starts-with ".") }
  | uniq
}

def shadowing-sources [root: string] {
  glob ($root | path join "**" "*.ts") --exclude ["**/*.d.ts" "**/node_modules/**"]
  | where {|file| (($file | str replace -r '\.ts$' '.d.ts') | path exists) }
}

def nested-duplicates [dir: string, root: string] {
  let source = ($dir | path join "src")
  glob ($root | path join "**" "*") --no-file --no-symlink --exclude ["**/node_modules/**"]
  | where {|found|
    let parts = ($found | path split)
    let count = ($parts | length)
    $count >= 2 and ($parts | last) == ($parts | get ($count - 2))
  }
  | where {|found|
    # A dir the output mirrors from src is a legitimate repeated name (lib/lib
    # from src/lib). One with no counterpart in src is a copy nested into
    # itself.
    not (($source | path join ($found | path relative-to $root)) | path exists)
  }
}

def prisma-json-types [schema: string] {
  let lines = (read-text $schema | lines)
  mut types = []
  for index in 1..<($lines | length) {
    if (($lines | get $index) | parse -r '\w+\s+Json\??' | is-empty) { continue }
    let annotation = (($lines | get ($index - 1)) | parse -r '///\s+\[(?<name>[\w\[\]]+)\]' | get -o 0.name)
    if $annotation != null {
      $types = ($types | append ($annotation | str replace -r '\[\]$' ''))
    }
  }
  $types | uniq
}

def check-entry [dir: string, entry: string] {
  if not ($entry | path exists) {
    return [$"($entry | path relative-to $dir) is missing — the build emitted no declarations"]
  }
  let base_dir = ($entry | path dirname)
  reexport-specifiers $entry
  | each {|spec| { spec: $spec, resolved: (resolve-specifier $base_dir $dir $spec) } }
  | where {|hit| $hit.resolved == null }
  | each {|hit|
    $"($entry | path relative-to $dir) re-exports '($hit.spec)' but no such file was emitted. Consumers resolve it to 'any' under skipLibCheck, which silently drops every type from that module."
  }
}

def check-prisma [dir: string, roots: list<string>] {
  let schema = ($dir | path join "prisma" "schema.prisma")
  if not ($schema | path exists) { return [] }
  let annotated = (prisma-json-types $schema)
  if ($annotated | is-empty) { return [] }

  let json_types = (
    $roots
    | each {|root| $dir | path join $root "json-types.d.ts" }
    | where {|file| ($file | path exists) }
    | get -o 0
  )
  let declaration_errors = if $json_types == null {
    ["json-types.d.ts was not emitted — the PrismaJson augmentation will not reach consumers"]
  } else {
    let content = (read-text $json_types)
    let rel = ($json_types | path relative-to $dir)
    let namespace = if ($content | find -r 'namespace PrismaJson' | is-empty) {
      [$"($rel) does not declare the PrismaJson namespace"]
    } else { [] }
    $namespace | append (
      $annotated
      | where {|type| ($content | find -r $"\\b\(type|interface\)\\s+($type)\\b" | is-empty) }
      | each {|type| $"($rel) does not declare '($type)' used by prisma/schema.prisma" }
    )
  }

  let models_dir = (
    $roots
    | each {|root| $dir | path join $root "generated" "client" "models" }
    | where {|found| ($found | path exists) }
    | get -o 0
  )
  let model_errors = if $models_dir == null {
    ["generated/client/models was not emitted — the generated prisma client was not copied into the output dir"]
  } else {
    let models = (glob ($models_dir | path join "*.d.ts") | each {|file| read-text $file } | str join "\n")
    $annotated
    | where {|type| not ($models | str contains $"PrismaJson.($type)") }
    | each {|type| $"no model in ($models_dir | path relative-to $dir) references 'PrismaJson.($type)' — prisma-json-types-generator did not annotate the client" }
  }

  $declaration_errors | append $model_errors
}

def check-package [dir: string] {
  let manifest = (open ($dir | path join "package.json"))
  let roots = (output-roots $dir $manifest)
  if ($roots | is-empty) { return null }

  let entry = (declaration-entry $dir $manifest)
  let entry_errors = if $entry == null { [] } else { check-entry $dir $entry }

  let layout_errors = (
    $roots | each {|root|
      let full = ($dir | path join $root)
      let shadowing = (
        shadowing-sources $full
        | each {|file|
          $"($file | path relative-to $dir) is a raw source file sitting next to its emitted .d.ts. TypeScript may resolve consumers to the source instead of the declaration, which drops every type export from that module."
        }
      )
      let nested = (
        nested-duplicates $dir $full
        | each {|found| $"($found | path relative-to $dir) looks like a copy nested into itself instead of replacing it — check the cp -r in the build" }
      )
      $shadowing | append $nested
    } | flatten
  )

  {
    name: ($manifest | get -o name | default ($dir | path basename))
    roots: $roots
    errors: ($entry_errors | append $layout_errors | append (check-prisma $dir $roots))
  }
}

# Verify that every built workspace package emitted a complete type artifact.
export def verify-dist [
  --package (-p): string # only this package directory (default: every built package)
  --quiet (-q) # print failures only
]: nothing -> nothing {
  let root = (workspace-root (pwd))
  let dirs = if $package != null {
    [($package | path expand)]
  } else {
    glob ($root | path join "**" "package.json") --exclude ["**/.*/**" "**/node_modules/**" "**/dist/**" "**/lib/**" "**/bundle/**"]
    | each {|manifest| $manifest | path dirname }
    | sort
  }

  let results = ($dirs | each {|dir| check-package $dir } | compact)

  if ($results | is-empty) {
    print $"No built package found under ($root)."
    return
  }

  for result in $results {
    if ($result.errors | is-empty) {
      if not $quiet { print $"(ansi green)ok(ansi reset)   ($result.name) \(($result.roots | str join ', ')\)" }
      continue
    }
    print $"(ansi red)fail(ansi reset) ($result.name)"
    for problem in $result.errors { print $"       - ($problem)" }
  }

  let failed = ($results | where {|result| ($result.errors | is-not-empty) })
  if ($failed | is-not-empty) {
    error make --unspanned {
      msg: $"($failed | length) of ($results | length) built package\(s\) emitted an incomplete artifact."
    }
  }

  if not $quiet { print $"\n($results | length) package\(s\) verified." }
}
