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
# Source: commitlint-conventional + Redocly type-enum.
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
    let config_file = (
        $candidates
        | where { |p| $p | path exists }
        | first
    )

    if ($config_file | is-empty) {
        return []
    }

    let content = (open --raw $config_file)

    # package.json: parse as JSON, only look inside commitlint key (avoid false positives).
    if ($config_file | str ends-with "package.json") {
        let pkg = (try { open $config_file } catch { return [] })
        let cl = ($pkg | get -o "commitlint")
        if ($cl == null) { return [] }
        let type_enum = ($cl | get -o "rules" | default {} | get -o "type-enum")
        if ($type_enum != null and ($type_enum | length) >= 3) {
            return ($type_enum | get 2)  # [level, when, [types]] format
        }
        let extends_list = ($cl | get -o "extends" | default [])
        if ($extends_list | any { |e| $e | str contains "config-conventional" }) {
            return $WORK_CONVENTIONAL_DEFAULTS
        }
        return []
    }

    # .js/.cjs/.mjs: multi-line tolerant regex on full content.
    # (?s) makes . match newlines so .*? spans multi-line arrays.
    # Accepts both single and double quotes around type-enum key.
    let match = (
        $content
        | parse --regex `(?s)["']type-enum["']\s*:\s*\[\s*\d+\s*,\s*["'][^"']+["']\s*,\s*\[(.*?)\]`
    )

    if ($match | is-empty) {
        if ($content | str contains "config-conventional") {
            return $WORK_CONVENTIONAL_DEFAULTS
        }
        print $"⚠️  ($config_file) — type-enum niewykryty. Użyj --type aby wymusić prefix."
        return []
    }

    # Extract quoted identifiers from the captured array body
    $match.capture0.0
    | parse --regex `["']([^"']+)["']`
    | get capture0
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

    let common_dir_r = (do { ^git rev-parse --path-format=absolute --git-common-dir } | complete)
    if $common_dir_r.exit_code != 0 {
        error make { msg: "Failed to resolve git common dir" }
    }
    let common_dir_raw = ($common_dir_r.stdout | str trim)
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
    let in_repo = ((do { ^git rev-parse --show-toplevel } | complete | get exit_code) == 0)
    let name = (
        if $in_repo {
            (work repo-info | get name)
        } else {
            "scratch"
        }
    )
    $env.HOME | path join "Code" "personal" "bazgroly" $name
}

# Verify all required CLI tools are available. Errors with install hint if missing.
def "work deps-preflight" []: nothing -> nothing {
    let required = ["git" "tmux" "sesh" "tv" "jq" "flock"]
    let optional = ["gtimeout" "fzf"]  # gtimeout = coreutils, fzf = fallback for tv

    let missing = ($required | where { |c| (which $c | is-empty) })
    if ($missing | is-not-empty) {
        error make {
            msg: $"Missing required dependencies: ($missing | str join ', '). Install: brew install ($missing | str join ' ')"
        }
    }

    let missing_optional = ($optional | where { |c| (which $c | is-empty) })
    if ($missing_optional | is-not-empty) {
        print $"⚠️  Optional missing: ($missing_optional | str join ', '). Install via: brew install coreutils fzf"
    }
}

# Stub — full cheatsheet implemented in Phase 7.
def "work help" []: nothing -> nothing {
    print "work help — full cheatsheet in Phase 7. For now use the plan/spec docs."
}

# Create a new worktree + tmux session + layout.
# Phase 4: full collision detection, commitlint enforcement, base-ref picker.
def "work new" [
    name: string  # Branch name (with or without conventional prefix)
    --from: string = ""  # Custom base ref (default: origin/<default-branch>)
    --type: string = ""  # Conventional commit type prefix (skip picker)
    --pick-from         # Interactive picker for base ref
    --no-prefix         # Skip commitlint enforcement
    --json              # Output JSON result
]: nothing -> any {
    work deps-preflight

    let info = (work repo-info)
    let repo = $info.name
    let parent = $info.root
    let default_branch = $info.default_branch

    # --- Base ref resolution ---
    let base_ref = (
        if $pick_from {
            let env_repo = $info.root
            let picked = (
                if (which tv | is-not-empty) {
                    with-env { WORK_REPO: $env_repo } {
                        ^tv --channel work-base-refs | str trim
                    }
                } else {
                    let candidates = (^git -C $info.root for-each-ref --format='%(refname:short)' refs/remotes/origin/ refs/heads/ | lines)
                    $candidates | str join "\n" | ^fzf --prompt "Base ref: " | str trim
                }
            )
            if ($picked | is-empty) { error make { msg: "No base ref selected, aborting." } }
            $picked
        } else if ($from | is-empty) {
            $"origin/($default_branch)"
        } else {
            $from
        }
    )

    # --- Commitlint enforcement ---
    let allowed_types = (work load-commitlint-types $info.root)
    let has_enforcement = (not ($allowed_types | is-empty))
    let has_slash = ($name | str contains "/")

    mut final_name = $name

    if $has_enforcement and not $has_slash and not $no_prefix {
        if not ($type | is-empty) {
            if not ($type in $allowed_types) {
                error make { msg: $"Type '($type)' not in allowed list: ($allowed_types | str join ', ')" }
            }
            $final_name = $"($type)/($name)"
        } else {
            # Interactive picker
            print $"\n⚠️  Repo '($info.name)' uses commitlint — choose branch type:"
            mut menu_lines = []
            for row in ($allowed_types | enumerate) {
                let emoji = ($WORK_PREFIX_EMOJI | get --optional $row.item | default "  ")
                let desc = ($WORK_PREFIX_DESC | get --optional $row.item | default "")
                $menu_lines = ($menu_lines | append $"  [($row.index + 1)] ($emoji) ($row.item)      ($desc)")
            }
            print ($menu_lines | str join "\n")
            print "  [a] abort"
            let choice = (input "Choice: ")
            if $choice == "a" or ($choice | is-empty) {
                error make { msg: "Aborted." }
            }
            let idx = (($choice | into int) - 1)
            if $idx < 0 or $idx >= ($allowed_types | length) {
                error make { msg: $"Invalid choice: ($choice)" }
            }
            let chosen_type = ($allowed_types | get $idx)
            $final_name = $"($chosen_type)/($name)"
            print $"→ branch: ($final_name)"
        }
    }

    # Snapshot final_name as immutable — Nu forbids capturing mut vars in closures.
    let branch_name = $final_name

    let wt_path = (work worktree-path $repo $branch_name)

    # Auto-attach if worktree already exists on disk
    if ($wt_path | path exists) {
        let session = (work session-name $repo $branch_name)
        print $"Worktree exists, connecting to session ($session)"
        ^sesh connect $session
        return
    }

    # Enable per-worktree config (idempotent)
    ^git -C $parent config extensions.worktreeConfig true | ignore

    # Fresh fetch (timeout 5s)
    let fetch_ref = ($base_ref | str replace "origin/" "")
    let fetch = (do { ^gtimeout 5 git -C $parent fetch origin $fetch_ref } | complete)
    if $fetch.exit_code != 0 {
        print $"⚠️  fetch failed/timeout — using local ($base_ref)"
    }

    # --- Collision check ---
    let branch_exists_local = (
        (do { ^git -C $parent rev-parse --verify --quiet $"refs/heads/($branch_name)" } | complete | get exit_code) == 0
    )
    let branch_exists_remote = (
        (do { ^git -C $parent rev-parse --verify --quiet $"refs/remotes/origin/($branch_name)" } | complete | get exit_code) == 0
    )
    let exists_anywhere = ($branch_exists_local or $branch_exists_remote)

    mut should_create_branch = true

    if $exists_anywhere {
        print $"\n⚠️  Branch '($branch_name)' already exists:"
        if $branch_exists_local { print "    local:  exists" }
        if $branch_exists_remote { print $"    remote: origin/($branch_name)" }
        print ""
        print "What do you want to do?"
        print "  [c] checkout existing branch into worktree (skip fresh start)"
        print "  [n] new name — enter a different name"
        print "  [a] abort  (default)"
        let choice = (input "Choice [c/n/a]: ")
        match $choice {
            "c" => { $should_create_branch = false }
            "n" => {
                let new_name = (input "New branch name: ")
                if ($new_name | is-empty) { error make { msg: "Aborted." } }
                work new $new_name --from $base_ref
                return
            }
            _ => { error make { msg: "Aborted." } }
        }
    }

    # Advisory lock
    let pool_dir = ($env.HOME | path join "Code" "tree" $"wt-($repo)")
    if not ($pool_dir | path exists) { mkdir $pool_dir }
    let lock_file = ($pool_dir | path join ".lock")
    touch $lock_file  # flock needs file to exist

    let result = (
        if $should_create_branch {
            do { ^flock -n $lock_file git -C $parent worktree add -b $branch_name $wt_path $base_ref } | complete
        } else {
            do { ^flock -n $lock_file git -C $parent worktree add $wt_path $branch_name } | complete
        }
    )

    if $result.exit_code != 0 {
        error make { msg: $"work new failed: ($result.stderr)" }
    }

    # Persist metadata
    let session = (work session-name $repo $branch_name)
    ^git -C $wt_path config --worktree work.base $base_ref
    ^git -C $wt_path config --worktree work.session $session
    ^git -C $wt_path config --worktree work.branch $branch_name

    # Tmux session + layout
    ^tmux new-session -d -s $session -c $wt_path
    ^tmux send-keys -t $session "work" Enter

    ^sesh connect $session

    if $json {
        return {
            repo: $repo
            branch: $branch_name
            path: $wt_path
            session: $session
            base: $base_ref
            created: true
        }
    }
}

# Set up 4-window layout in current tmux session.
# Windows: terminal | git (lazygit) | claude | nvim (bazgroly/<repo>/)
# Idempotent — skips windows that already exist by name.
# Use this from inside any session (parent repo or worktree).
def work [
    --help (-h)  # Show cheatsheet (delegates to `work help`)
]: nothing -> nothing {
    if $help {
        work help
        return
    }

    if ($env.TMUX? == null) {
        print "work: not inside tmux. Run `tn` first."
        return
    }

    let term = $"\u{f120}  terminal"
    let git  = $"\u{e725}  git"
    let cc   = $"\u{f06a9}  claude"
    let edit = $"\u{e62b}  nvim"

    # BUG FIX from audit: use parent repo name even when in worktree.
    let bazgroly = (work bazgroly-path)
    if not ($bazgroly | path exists) {
        mkdir $bazgroly
    }

    # Window 1: rename caller window to terminal, lock auto-rename off.
    ^tmux set-window-option automatic-rename off
    ^tmux rename-window $term

    let existing = (^tmux list-windows -F "#{window_name}" | lines)

    for spec in [
        { name: $git,  cwd: $env.PWD, cmd: ["lazygit"] }
        { name: $cc,   cwd: $env.PWD, cmd: ["claude"] }
        { name: $edit, cwd: $bazgroly, cmd: ["nvim" $bazgroly] }
    ] {
        if not ($spec.name in $existing) {
            let wid = (^tmux new-window -d -P -F "#{window_id}" -n $spec.name -c $spec.cwd ...$spec.cmd | str trim)
            ^tmux set-window-option -t $wid automatic-rename off
            ^tmux rename-window -t $wid $spec.name
        }
    }

    ^tmux select-window -t:1
}
