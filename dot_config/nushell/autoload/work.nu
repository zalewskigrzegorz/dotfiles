# work.nu — git worktree workflow integration with sesh + tv + tmux.
#
# Subcommands (added in later phases):
#   work                 — 4-window layout in current tmux session
#   work new <name>      — create worktree + session + layout
#   work ls              — picker over all worktrees
#   work rm [branch]     — cleanup worktree + branch + session
#   work prune           — batch cleanup merged worktrees
#   work help            — cheatsheet
#
# All commands support --json for scripting.
# Source of truth spec: ~/Code/personal/bazgroly/dotfiles/specs/2026-05-26-work-worktree-design.md

# Emoji-prefix mapping for tmux session names.
# Source: commitlint-conventional + REDACTED_ORG type-enum.
# Used by `work normalize-session`.
const WORK_PREFIX_EMOJI = {
    feat: "✨"
    fix: "🐛"
    hotfix: "🚑"
    docs: "📝"
    tests: "🧪"
    test: "🧪"
    chore: "🧹"
    refactor: "♻"
    perf: "⚡"
    build: "📦"
    ci: "👷"
    revert: "⏪"
    style: "💄"
}

# Reverse table — for `work help` display.
const WORK_PREFIX_DESC = {
    feat: "new feature"
    fix: "bug fix"
    hotfix: "urgent prod fix"
    docs: "documentation"
    tests: "tests"
    chore: "maintenance"
    refactor: "code refactor"
    perf: "performance"
    build: "build system"
    ci: "CI/CD"
    revert: "revert previous commit"
    style: "formatting/style"
}

# Normalize branch name to tmux-safe session suffix.
# - "feat/billing-page"   -> "✨billing-page"
# - "fix/auth-loop"       -> "🐛auth-loop"
# - "wip/something"       -> "wip-something"  (unknown prefix → dash fallback)
# - "experimental"        -> "experimental"   (no prefix)
def "work normalize-session" [branch: string]: nothing -> string {
    if not ($branch | str contains "/") {
        return $branch
    }
    let parts = ($branch | split row --number 2 "/")
    let prefix = $parts.0
    let suffix = $parts.1
    let emoji = ($WORK_PREFIX_EMOJI | get --optional $prefix)
    if ($emoji | is-not-empty) {
        $"($emoji)($suffix)"
    } else {
        $"($prefix)-($suffix)"
    }
}

# Wrap normalized name with 🌿 prefix and repo scope.
# e.g. ("realm", "feat/billing-page") -> "🌿realm/✨billing-page"
def "work session-name" [repo: string, branch: string]: nothing -> string {
    let suffix = (work normalize-session $branch)
    $"🌿($repo)/($suffix)"
}

# Truncate session name to max 28 chars + ellipsis (tmux UI breaks ~30).
def "work truncate-session" [name: string, max: int = 28]: nothing -> string {
    if ($name | str length) > $max {
        ($name | str substring 0..($max - 1)) + "…"
    } else {
        $name
    }
}

# Conventional commit defaults (fallback when `extends config-conventional`).
const WORK_CONVENTIONAL_DEFAULTS = [
    "build" "chore" "ci" "docs" "feat" "fix"
    "perf" "refactor" "revert" "style" "test"
]

# Load allowed commit type prefixes from a repo's commitlint config.
# Returns empty list if no config found (= no enforcement).
# Returns conventional defaults if config extends config-conventional without override.
# Returns explicit type-enum list if found.
def "work load-commitlint-types" [repo_path: path]: nothing -> list<string> {
    let candidates = [
        ($repo_path | path join "commitlint.config.js")
        ($repo_path | path join "commitlint.config.cjs")
        ($repo_path | path join "commitlint.config.mjs")
        ($repo_path | path join "package.json")
    ]
    let found = ($candidates | where { |p| $p | path exists })

    if ($found | is-empty) {
        return []
    }

    let config_file = ($found | first)
    let content = (open --raw $config_file)

    # Look for a 'type-enum' line: 'type-enum': [2, 'always', ['a', 'b', ...]]
    let type_lines = ($content | lines | where { |l| $l | str contains "'type-enum'" })

    if ($type_lines | is-empty) {
        # No type-enum override — check for extends config-conventional
        if ($content | str contains "config-conventional") {
            return $WORK_CONVENTIONAL_DEFAULTS
        }
        print $"⚠️  ($config_file) — type-enum not found. Use --type to force a prefix."
        return []
    }

    let type_line = ($type_lines | first)

    # Split at '[' — last bracket group = the enum array
    let parts = ($type_line | split row "[")
    if ($parts | length) < 2 {
        return $WORK_CONVENTIONAL_DEFAULTS
    }
    let inner = ($parts | last | str replace --all "]" "" | str replace --all "," "" | str trim)

    # Extract quoted identifiers from the inner string
    $inner | parse --regex "'([^']+)'" | get capture0
}

# Resolve repo info regardless of whether we're in parent or worktree.
# Returns record with: name (basename of common dir parent), root (parent repo path),
# default_branch, common_dir (.git path), is_worktree (bool), worktree_path (if worktree).
def "work repo-info" []: nothing -> record {
    let toplevel = (do { ^git rev-parse --show-toplevel } | complete)
    if $toplevel.exit_code != 0 {
        error make { msg: "Not inside a git repository." }
    }
    let worktree_path = ($toplevel.stdout | str trim)

    let common_dir_raw = (^git rev-parse --path-format=absolute --git-common-dir | str trim)
    # common_dir = "/Users/greg/Code/realm/.git"
    # Strip trailing /.git to get parent repo root
    let parent_root = (
        if ($common_dir_raw | str ends-with "/.git") {
            $common_dir_raw | str substring 0..(($common_dir_raw | str length) - 6)
        } else {
            $common_dir_raw | path dirname
        }
    )
    let name = ($parent_root | path basename)

    let git_dir = (^git rev-parse --git-dir | str trim)
    let is_worktree = ($git_dir != ".git" and $git_dir != $common_dir_raw)

    let head_ref = (do { ^git symbolic-ref refs/remotes/origin/HEAD } | complete)
    let default_branch = (
        if $head_ref.exit_code == 0 {
            $head_ref.stdout | str trim | str replace "refs/remotes/origin/" ""
        } else {
            "master"
        }
    )

    {
        name: $name
        root: $parent_root
        default_branch: $default_branch
        common_dir: $common_dir_raw
        is_worktree: $is_worktree
        worktree_path: (if $is_worktree { $worktree_path } else { null })
    }
}

# Compute path for a worktree based on repo name + branch.
def "work worktree-path" [repo: string, branch: string]: nothing -> path {
    $env.HOME | path join "Code" "tree" $"wt-($repo)" $branch
}

# Compute bazgroly path for current repo (always uses parent repo name).
def "work bazgroly-path" []: nothing -> path {
    let info = (work repo-info)
    $env.HOME | path join "Code" "personal" "bazgroly" $info.name
}
