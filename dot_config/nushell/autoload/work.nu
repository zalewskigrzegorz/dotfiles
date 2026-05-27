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
# Commands return nu data — pipe `| to json` for scripting.
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

# Conventional commit defaults (fallback when `extends config-conventional`).
const WORK_CONVENTIONAL_DEFAULTS = [
    "build" "chore" "ci" "docs" "feat" "fix"
    "perf" "refactor" "revert" "style" "test"
]

# Load allowed commit type prefixes from a repo's commitlint config.
# Returns empty list if no config found (= no enforcement).
# Returns conventional defaults if config extends config-conventional without override.
# Returns explicit type-enum list if found.
def "work load-commitlint-types" [
    repo_path?: path  # Default: current working directory
]: nothing -> list<string> {
    let repo_path = (if ($repo_path | is-empty) { $env.PWD | path expand } else { $repo_path })
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

    let git_dir_r = (do { ^git rev-parse --git-dir } | complete)
    if $git_dir_r.exit_code != 0 { error make { msg: "Failed to resolve git-dir" } }
    let git_dir = ($git_dir_r.stdout | str trim)
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
        print -e $"⚠️  Optional missing: ($missing_optional | str join ', '). Install via: brew install coreutils fzf"
    }
}

# Find tmux sessions matching 🌿* that don't have a corresponding worktree.
# Useful for detecting sessions left behind after manual worktree removal.
def "work stale-sessions" []: nothing -> list<string> {
    let known = (work scan-worktrees | get session | where { |s| $s != "" })
    let all_r = (do { ^tmux list-sessions -F "#{session_name}" } | complete)
    if $all_r.exit_code != 0 { return [] }
    $all_r.stdout
    | lines
    | where { |s| $s | str starts-with "🌿" }
    | where { |s| not ($s in $known) }
}

# Kill all stale 🌿* tmux sessions (those without a corresponding worktree).
def "work clean-stale-sessions" []: nothing -> nothing {
    let stale = (work stale-sessions)
    if ($stale | is-empty) {
        print -e "No stale 🌿 sessions."
        return
    }
    for s in $stale {
        print -e $"Killing stale session: ($s)"
        ^tmux kill-session -t $s
    }
}

# Print cheatsheet for the work command family.
# In a worktree, also shows base/branch/path of the current worktree.
def "work help" []: nothing -> nothing {
    let in_repo = (try { work repo-info | is-not-empty } catch { false })

    print "📖 Work — worktree workflow"
    print ""
    print "KOMENDY"
    print "  work                       4-window layout (terminal/git/claude/nvim)"
    print "  work new                   Picker po branchach + Create new..."
    print "  work new <name>            Nowy worktree z origin/master (collision → prompt)"
    print "  work new <name> --pick-from  Picker po base ref, potem worktree"
    print "  work new <name> --from <r> Worktree z custom base ref"
    print "  work new <name> --type <t> Force prefix bez picker (skip commitlint)"
    print "  work ls                    Zwraca listę worktree jako nu records (tabela)"
    print "  work switch (sw)           Picker po worktree → przełącz sesję (sesh)"
    print "  work rm [branch]           Usuń worktree + branch + sesję (atomowo)"
    print "  work prune                 Batch: usuń wszystkie merged-into-master"
    print "  work prune --dry-run       Wypisz kandydatów bez usuwania"
    print "  work stale-sessions        Lista sesji 🌿* bez worktree"
    print "  work clean-stale-sessions  Usuń stare sesje 🌿* bez worktree"
    print "  work help                  Ten ekran"
    print ""
    print "Komendy zwracają nu data — dopisz `| to json` gdy chcesz JSON (np `work ls | to json`)."
    print ""
    print "🆕 NOWY BRANCH ZAWSZE ZE ŚWIEŻEGO ORIGIN/MASTER"
    print "  work new fix-auth          → git fetch origin master"
    print "                             → git worktree add -b fix-auth <path> origin/master"
    print ""
    print "📍 BASE REF PERSISTENCE"
    print "  work new zapisuje base/session/branch w git config --worktree."
    print "  Widzisz w: work ls preview, tmux status-right, work help (w sesji)."

    # If we're inside a worktree, print its context
    if $in_repo {
        # Re-resolve via work repo-info to get the record
        let info = (work repo-info)
        if $info.is_worktree {
            let wt_path = $info.worktree_path
            let base_r = (do { ^git -C $wt_path config --worktree work.base } | complete)
            let base = ($base_r.stdout | str trim)
            let branch_r = (do { ^git -C $wt_path config --worktree work.branch } | complete)
            let branch = ($branch_r.stdout | str trim)
            print ""
            print "🌿 JESTEŚ W WORKTREE:"
            print $"  branch: ($branch)"
            print $"  base:   ($base)"
            print $"  path:   ($wt_path)"
        }
    }

    print ""
    print "💾 COMMIT + PUSH W WORKTREE"
    print "  Commit ZAWSZE leci na branch feature. Parent repo nietknięty."
    print "  cd <worktree-path>; git commit; git push -u origin <branch>"
    print "  (lazygit w oknie git robi to samo wizualnie)"
    print ""
    print "🔀 EMOJI-PREFIX MAPPING (commitlint integration)"
    print "  feat/     → ✨   fix/      → 🐛   hotfix/   → 🚑"
    print "  docs/     → 📝   tests/    → 🧪   chore/    → 🧹"
    print "  refactor/ → ♻    perf/     → ⚡   build/    → 📦"
    print "  ci/       → 👷   revert/   → ⏪   style/    → 💄"
    print ""
    print "🧠 MENTAL MODEL"
    print "  Worktree = osobny katalog wskazujący na branch."
    print "  Każdy worktree = własny HEAD → commitujesz niezależnie."
    print "  Wszystkie dzielą jedno .git/ (objects, refs)."
}

# Create a new worktree + tmux session + layout.
# Phase 4: full collision detection, commitlint enforcement, base-ref picker.
# name is optional — omit to get an interactive branch picker (TV or fzf fallback).
def "work new" [
    name: string@"work _complete-branches-no-wt" = ""  # Branch name (empty = interactive picker)
    --from: string = ""  # Custom base ref (default: origin/<default-branch>)
    --type: string = ""  # Conventional commit type prefix (skip picker)
    --pick-from         # Interactive picker for base ref
    --no-prefix         # Skip commitlint enforcement
]: nothing -> any {
    work deps-preflight

    let info = (work repo-info)
    let repo = $info.name
    let parent = $info.root
    let default_branch = $info.default_branch

    # --- Branch name resolution (picker when name empty) ---
    mut effective_name = $name

    if ($name | is-empty) {
        let env_repo = $info.root
        let picked = (
            if (which tv | is-not-empty) {
                with-env { WORK_REPO: $env_repo } {
                    ^tv work-branches | str trim
                }
            } else {
                let local_r = (do { ^git -C $info.root for-each-ref --format='%(refname:short)' refs/heads/ } | complete)
                let local_b = (if $local_r.exit_code == 0 { $local_r.stdout | lines } else { [] })
                let remote_r = (do { ^git -C $info.root for-each-ref --format='%(refname:short)' refs/remotes/origin/ } | complete)
                let remote_b = (if $remote_r.exit_code == 0 { $remote_r.stdout | lines | where { |b| $b != "HEAD" } } else { [] })
                let cands = ($local_b ++ $remote_b ++ ["+ Create new branch..."])
                $cands | str join "\n" | ^fzf --prompt "Branch: " | str trim
            }
        )
        if ($picked | is-empty) { error make { msg: "No branch selected." } }

        if $picked == "+ Create new branch..." {
            let new_name = (input "New branch name: ")
            if ($new_name | is-empty) { error make { msg: "No name given." } }
            $effective_name = $new_name
        } else if ($picked | str starts-with "origin/") {
            $effective_name = ($picked | str replace "origin/" "")
        } else {
            $effective_name = $picked
        }
    }

    # Snapshot effective_name as immutable before any closure usage.
    let input_name = $effective_name

    # --- Base ref resolution (--from | --pick-from | default origin/<default>) ---
    let base_ref = (
        if $pick_from {
            let env_repo = $info.root
            let picked = (
                if (which tv | is-not-empty) {
                    with-env { WORK_REPO: $env_repo } {
                        ^tv work-base-refs | str trim
                    }
                } else {
                    let cands_r = (do { ^git -C $info.root for-each-ref --format='%(refname:short)' refs/remotes/origin/ refs/heads/ } | complete)
                    let candidates = (if $cands_r.exit_code == 0 { $cands_r.stdout | lines } else { [] })
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
    let has_slash = ($input_name | str contains "/")

    mut final_name = $input_name

    if $has_enforcement and not $has_slash and not $no_prefix {
        if not ($type | is-empty) {
            if not ($type in $allowed_types) {
                error make { msg: $"Type '($type)' not in allowed list: ($allowed_types | str join ', ')" }
            }
            $final_name = $"($type)/($input_name)"
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
            let idx = (
                try { ($choice | into int) - 1 } catch {
                    error make { msg: $"Invalid choice: '($choice)' — expected number from menu." }
                }
            )
            if $idx < 0 or $idx >= ($allowed_types | length) {
                error make { msg: $"Invalid choice: ($choice) — out of range." }
            }
            let chosen_type = ($allowed_types | get $idx)
            $final_name = $"($chosen_type)/($input_name)"
            print $"→ branch: ($final_name)"
        }
    }

    # Snapshot final_name as immutable — Nu forbids capturing mut vars in closures.
    let branch_name = $final_name

    let wt_path = (work worktree-path $repo $branch_name)

    # Auto-attach if worktree already exists on disk
    if ($wt_path | path exists) {
        let session = (work session-name $repo $branch_name)
        let session_exists = ((do { ^tmux has-session -t $session } | complete).exit_code == 0)
        if $session_exists {
            print -e $"Worktree exists, connecting to session ($session)"
            ^sesh connect $session
        } else {
            print -e $"Worktree exists (no tmux session), connecting by path ($wt_path)"
            ^sesh connect $wt_path
        }
        let stored_base = (do { ^git -C $wt_path config --worktree work.base } | complete | get stdout | str trim)
        return {
            repo: $repo
            branch: $branch_name
            path: $wt_path
            session: $session
            base: (if ($stored_base | is-empty) { "(unknown)" } else { $stored_base })
            created: false
        }
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
                if $no_prefix {
                    work new $new_name --from $base_ref --no-prefix
                } else if (not ($type | is-empty)) {
                    work new $new_name --from $base_ref --type $type
                } else {
                    work new $new_name --from $base_ref
                }
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

    if $result.exit_code == 1 and ($result.stderr | str trim | is-empty) {
        # flock -n returns 1 with no stderr when lock unavailable
        error make { msg: $"work new: another `work new` is in progress for ($repo). Try again in a moment." }
    }
    if $result.exit_code != 0 {
        error make { msg: $"work new failed: ($result.stderr)" }
    }

    # Persist metadata
    let session = (work session-name $repo $branch_name)
    if $should_create_branch {
        ^git -C $wt_path config --worktree work.base $base_ref
    } else {
        ^git -C $wt_path config --worktree work.base "(existing branch)"
    }
    ^git -C $wt_path config --worktree work.session $session
    ^git -C $wt_path config --worktree work.branch $branch_name

    # Tmux session + layout
    ^tmux new-session -d -s $session -c $wt_path
    ^tmux send-keys -t $session "work" Enter

    let result = {
        repo: $repo
        branch: $branch_name
        path: $wt_path
        session: $session
        base: $base_ref
        created: true
    }

    work cache-invalidate

    ^sesh connect $session
    $result
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

# Helper: gather metadata for all worktrees in the pool.
# Uses `git worktree list --porcelain` from the parent repo as canonical source —
# avoids naive subdir scan that incorrectly includes nested dirs (Bug 2).
# Returns list of records: {repo, branch, path, session, session_active, base, status, head}
def "work scan-worktrees" []: nothing -> list<record> {
    let pool = ($env.HOME | path join "Code" "tree")
    if not ($pool | path exists) { return [] }

    let repo_dirs = (
        ls -s $pool
        | where type == dir and ($it.name | str starts-with "wt-")
    )

    let candidates = (
        $repo_dirs | each { |repo_dir|
            let repo_name = ($repo_dir.name | str substring 3..)
            let repo_pool = ($pool | path join $repo_dir.name)
            let parent_repo = ($env.HOME | path join "Code" $repo_name)

            # Need parent repo to have .git for porcelain query
            if not ($parent_repo | path join ".git" | path exists) {
                return []
            }

            let porcelain = (do { ^git -C $parent_repo worktree list --porcelain } | complete)
            if $porcelain.exit_code != 0 { return [] }

            # Parse porcelain into {path, branch} records
            let entries = (
                $porcelain.stdout
                | lines
                | reduce -f [] { |line, acc|
                    if ($line | str starts-with "worktree ") {
                        let wt_path = ($line | str replace "worktree " "")
                        $acc | append { path: $wt_path, branch: null }
                    } else if ($line | str starts-with "branch ") {
                        let branch = ($line | str replace "branch refs/heads/" "")
                        let last = ($acc | last)
                        ($acc | drop 1) | append ($last | merge { branch: $branch })
                    } else {
                        $acc
                    }
                }
            )

            # Only entries inside the pool dir (excludes main parent repo)
            $entries
            | where ($it.path | str starts-with $repo_pool)
            | each { |e|
                { repo: $repo_name, branch: ($e.branch | default "(detached)"), path: $e.path }
            }
        }
        | flatten
    )

    $candidates | par-each { |wt|
        let status_r = (do { ^git -C $wt.path status --porcelain } | complete)
        let dirty = ($status_r.stdout | str trim | is-not-empty)

        let base_r = (do { ^git -C $wt.path config --worktree work.base } | complete)
        let base = ($base_r.stdout | str trim)

        let session_r = (do { ^git -C $wt.path config --worktree work.session } | complete)
        let session = ($session_r.stdout | str trim)

        # Bug 3/8b: session_active must be false when session is empty or non-🌿
        let has_sess = (
            if ($session | is-empty) or (not ($session | str starts-with "🌿")) {
                false
            } else {
                ((do { ^tmux has-session -t $session } | complete).exit_code == 0)
            }
        )

        let head_r = (do { ^git -C $wt.path rev-parse HEAD } | complete)
        let head = ($head_r.stdout | str trim | str substring 0..6)

        $wt | merge {
            base: (if ($base | is-empty) { "(unknown)" } else { $base })
            session: $session
            session_active: $has_sess
            status: (if $dirty { "dirty" } else { "clean" })
            head: $head
        }
    }
}

# List all worktrees in the pool.
# Returns nu records (auto-printed as table). Pipe to `| to json` for JSON.
# --no-cache: force re-scan.
# Picker lives in `bin/sesh-picker` bound to ^w — not here.
def "work ls" [
    --no-cache   # Force re-scan (skip TTL cache)
]: nothing -> list<record> {
    let cached = (if $no_cache { null } else { work cache-read })
    let worktrees = (
        if ($cached | is-empty) {
            let fresh = (work scan-worktrees)
            work cache-write $fresh
            $fresh
        } else {
            $cached
        }
    )

    # Warn about stale 🌿 sessions that have no corresponding worktree (to stderr)
    let stale = (work stale-sessions)
    if ($stale | is-not-empty) {
        print -e $"⚠️  ($stale | length) stale 🌿 session\(s\) without worktree:"
        for s in $stale { print -e $"    ($s)" }
        print -e "    Run `work clean-stale-sessions` to kill them."
    }

    $worktrees
}

# Interactive picker over all worktrees → connect to its tmux session (sesh).
# Worktree-only (unlike `s` which lists all sesh sessions).
# Usage: work switch   (alias: work sw)
def "work switch" []: nothing -> nothing {
    let worktrees = (work scan-worktrees)
    if ($worktrees | is-empty) {
        print "No worktrees. Use `work new <branch>` to create one."
        return
    }

    # Pick a worktree path (tv worktrees channel → fzf fallback)
    let picked_raw = (
        if (which tv | is-not-empty) {
            ^tv worktrees | str trim
        } else {
            $worktrees
            | each { |w| $w.path }
            | str join (char newline)
            | ^fzf --prompt "Switch to worktree: "
            | str trim
        }
    )
    if ($picked_raw | is-empty) { return }

    # Normalize: tv returns trailing-slash paths; scan-worktrees paths have none.
    let picked = ($picked_raw | str trim --right --char "/")

    let match = ($worktrees | where path == $picked)
    if ($match | is-empty) {
        # Path not in scan (edge case) — connect by path directly, sesh will handle it.
        ^sesh connect $picked
        return
    }

    let wt = ($match | first)
    if ($wt.session | is-empty) {
        # Worktree without a recorded session (created manually) — connect by path.
        print $"No session recorded for ($wt.branch); connecting by path."
        ^sesh connect $wt.path
    } else {
        ^sesh connect $wt.session
    }
}

# Short alias for `work switch`.
def "work sw" []: nothing -> nothing {
    work switch
}

const WORK_CACHE_TTL_SEC = 5

def "work cache-path" []: nothing -> path {
    $env.HOME | path join "Code" "tree" ".work-ls-cache.json"
}

def "work cache-invalidate" []: nothing -> nothing {
    let cache = (work cache-path)
    if ($cache | path exists) { rm $cache }
}

# Read cache if fresh enough. Returns null if stale, missing, or old schema version.
def "work cache-read" []: nothing -> any {
    let cache = (work cache-path)
    if not ($cache | path exists) { return null }

    let content = (try { open $cache } catch { return null })
    if ($content | is-empty) { return null }

    # Version guard — old caches (missing version or version != 2) are rejected
    if (($content | get -o version | default 1) != 2) {
        return null
    }

    let generated = (try { $content.generated_at | into datetime } catch { return null })
    let age = ((date now) - $generated)
    let age_sec = ($age | into int) / 1_000_000_000

    if $age_sec > $WORK_CACHE_TTL_SEC {
        return null
    }
    $content.worktrees
}

def "work cache-write" [worktrees: list]: nothing -> nothing {
    let cache = (work cache-path)
    let pool = ($env.HOME | path join "Code" "tree")
    if not ($pool | path exists) { return }
    {
        version: 2
        generated_at: (date now | format date "%+")
        worktrees: $worktrees
    } | to json | save -f $cache
}

# Remove worktree + tmux session + (optional) git branch.
# Atomic: removes worktree, kills session, optionally deletes branch.
# - work rm <branch>  → cleanup specified branch (or cross-repo search)
# - work rm <path>    → cleanup by worktree path (unambiguous, used by prune)
# - work rm           → picker (fzf over all worktrees)
def "work rm" [
    branch?: string@"work _complete-worktrees"  # Worktree branch name OR path (e.g. "feat/billing-page" or "/path/to/wt")
    --force          # Skip dirty check
    --keep-branch    # Don't delete git branch
]: nothing -> record {
    work deps-preflight
    let info = (work repo-info)

    # Detect if the arg is an existing directory path (path-mode vs branch-mode).
    let arg_is_path = (
        ($branch | is-not-empty)
        and ($branch | path exists)
        and (($branch | path type) == "dir")
    )

    # PATH MODE: arg is a direct worktree path — no branch→path resolution needed.
    let wt_path = (
        if $arg_is_path {
            $branch | path expand
        } else {
            # BRANCH MODE: resolve from picker or branch name.
            let target_b = (
                if ($branch | is-empty) {
                    let all = (work scan-worktrees)
                    if ($all | is-empty) {
                        error make { msg: "No worktrees. Use `work new <branch>` to create one." }
                    }
                    # TV worktrees channel (preferred) → fzf fallback
                    let picked_raw = (
                        if (which tv | is-not-empty) {
                            ^tv worktrees | str trim
                        } else {
                            $all
                            | each { |wt| $"($wt.branch)\t($wt.status)\tfrom ($wt.base)" }
                            | str join "\n"
                            | ^fzf --prompt "Remove worktree: " --delimiter "\t" --with-nth=1
                            | str trim
                        }
                    )
                    if ($picked_raw | is-empty) { error make { msg: "Nothing picked." } }
                    # TV returns a path → map to branch; fzf returns "branch\t..." → first column
                    let picked = ($picked_raw | str trim --right --char "/")
                    let by_path = ($all | where path == $picked)
                    if ($by_path | is-not-empty) {
                        ($by_path | first | get branch)
                    } else {
                        $picked_raw | split row "\t" | first
                    }
                } else {
                    $branch
                }
            )

            # Resolve path from branch name (local pool first, then cross-repo search).
            let wt_path_local = (work worktree-path $info.name $target_b)
            if ($wt_path_local | path exists) {
                $wt_path_local
            } else {
                let matches = (
                    work scan-worktrees
                    | where branch == $target_b
                )
                if ($matches | length) == 0 {
                    error make { msg: $"No worktree for branch '($target_b)' found in any repo." }
                } else if ($matches | length) > 1 {
                    let repos = ($matches | get repo | str join ", ")
                    error make { msg: $"Ambiguous branch '($target_b)' — exists in: ($repos). Run `cd ~/Code/<repo> && work rm ($target_b)` to disambiguate." }
                } else {
                    let m = ($matches | first)
                    let repo = $m.repo
                    print -e $"Found ($target_b) in repo ($repo) — switching from ($info.name)."
                    $m.path
                }
            }
        }
    )

    # Derive target_branch from path (path-mode: read from git config; branch-mode: already known).
    let target_branch = (
        if $arg_is_path {
            let b = (do { ^git -C $wt_path config --worktree work.branch } | complete | get stdout | str trim)
            if ($b | is-empty) { ($wt_path | path basename) } else { $b }
        } else {
            # In branch-mode, re-derive from what was passed (picker or arg).
            # We need to re-extract target_b here — compute from wt_path basename as fallback.
            let stored = (do { ^git -C $wt_path config --worktree work.branch } | complete | get stdout | str trim)
            if ($stored | is-not-empty) { $stored } else { $wt_path | path basename }
        }
    )

    # Resolve which parent repo this worktree belongs to
    let _common_r = (do { ^git -C $wt_path rev-parse --path-format=absolute --git-common-dir } | complete)
    if $_common_r.exit_code != 0 {
        error make { msg: $"Cannot resolve git-common-dir for ($wt_path)" }
    }
    let _cd = ($_common_r.stdout | str trim)
    let target_repo_root = (
        if ($_cd | str ends-with "/.git") {
            $_cd | str substring 0..(($_cd | str length) - 6)
        } else {
            $_cd | path dirname
        }
    )
    let target_repo_name = ($target_repo_root | path basename)

    # Auto-switch away if we're inside the worktree we're trying to remove
    if $info.is_worktree and ($info.worktree_path == $wt_path) {
        let other_sessions = (
            do { ^tmux list-sessions -F "#{session_name}" } | complete
            | get stdout | lines
            | where { |s| not ($s | str starts-with "🌿") }
        )
        let parent_session = (
            if ($other_sessions | is-empty) {
                ^tmux new-session -d -s "main"
                "main"
            } else {
                $other_sessions | first
            }
        )
        print -e $"🔀 Switching to ($parent_session) before removing ($target_branch)..."
        ^tmux switch-client -t $parent_session
        # cd to repo root so nushell's $env.PWD stays valid after worktree dir is removed.
        # Without this, nushell raises "PWD points to a non-existent directory" at every
        # subsequent command boundary and the branch-delete + kill-session never run.
        cd $target_repo_root
    }

    # Dirty check
    let dirty_r = (do { ^git -C $wt_path status --porcelain } | complete)
    let dirty = ($dirty_r.stdout | str trim | is-not-empty)
    if $dirty and (not $force) {
        print -e $"⚠️  Worktree ($target_branch) has uncommitted changes."
        let yn = (input "Force remove? [y/N]: ")
        if $yn != "y" { error make { msg: "Aborted." } }
    }

    # Prefer stored session name; fall back to computed name if not recorded.
    let stored_session_r = (do { ^git -C $wt_path config --worktree work.session } | complete)
    let stored_session = ($stored_session_r.stdout | str trim)
    let session = (
        if ($stored_session | is-not-empty) {
            $stored_session
        } else {
            work session-name $target_repo_name $target_branch
        }
    )

    # Cleanup ORDER: worktree first, then branch, then cache, then output, FINALLY session-kill.
    # kill-session is last because in self-worktree mode it SIGHUPs the current nu shell,
    # killing every command that follows it.
    ^git -C $target_repo_root worktree remove $wt_path --force
    if not $keep_branch {
        let r = (do { ^git -C $target_repo_root branch -d $target_branch } | complete)
        if $r.exit_code != 0 {
            print -e $"⚠️  Branch ($target_branch) not fully merged — use 'git branch -D ($target_branch)' to force-delete."
        }
    }

    work cache-invalidate

    let result = { removed: $target_branch, path: $wt_path, session: $session }
    print -e $"✅ Removed: ($target_branch)"
    do { ^tmux kill-session -t $session } | complete | ignore
    $result
}

# Batch-remove all worktrees whose branch is merged into the default branch
# of their OWN parent repo. Scans ALL pools (cross-repo). Interactive fzf -m.
def "work prune" [
    --dry-run  # Don't remove, just list candidates
]: nothing -> any {
    work deps-preflight

    let all = (work scan-worktrees)
    if ($all | is-empty) {
        print -e "No worktrees."
        return []
    }

    # For each clean worktree, check if merged into its own parent's default branch.
    # Returns augmented record with parent_root + is_merged fields; filter to merged ones.
    let candidates = (
        $all
        | where status == "clean"
        | each { |wt|
            # Resolve parent repo for this worktree
            let common_r = (do { ^git -C $wt.path rev-parse --path-format=absolute --git-common-dir } | complete)
            if $common_r.exit_code != 0 { return null }
            let cd = ($common_r.stdout | str trim)
            let root = (
                if ($cd | str ends-with "/.git") {
                    $cd | str substring 0..(($cd | str length) - 6)
                } else {
                    $cd | path dirname
                }
            )
            # Get default branch for this parent repo
            let head_ref = (do { ^git -C $root symbolic-ref refs/remotes/origin/HEAD } | complete)
            let default_branch = (
                if $head_ref.exit_code == 0 {
                    $head_ref.stdout | str trim | str replace "refs/remotes/origin/" ""
                } else {
                    "master"
                }
            )
            # Check merged
            let merged_r = (do { ^git -C $root branch --merged $default_branch } | complete)
            if $merged_r.exit_code != 0 { return null }
            let merged = (
                $merged_r.stdout
                | lines
                | each { |l| $l | str trim | str replace "* " "" }
                | where { |it| $it != $default_branch and $it != "" }
            )
            if not ($wt.branch in $merged) { return null }
            $wt | merge { parent_root: $root, default_branch: $default_branch }
        }
        | where { |it| $it != null }
    )

    if ($candidates | is-empty) {
        print -e "Nothing to prune (no merged + clean worktrees across all pools)."
        return []
    }

    if $dry_run {
        return $candidates
    }

    # Multi-select picker (fzf -m) — embed path as hidden second column so prune
    # can pass unambiguous paths to `work rm` (avoids cross-repo branch ambiguity).
    let lines = ($candidates | each { |c| $"($c.repo)/($c.branch)\t($c.path)" })
    let picked = (
        $lines
        | str join "\n"
        | ^fzf --multi --prompt "Prune (Tab to select multiple): " --delimiter "\t" --with-nth=1
        | lines
    )

    if ($picked | is-empty) { return [] }

    # Extract path (second tab-delimited field) — unambiguous even with duplicate branch names.
    let paths_to_remove = ($picked | each { |line| $line | split row "\t" | last })

    print -e $"Removing ($paths_to_remove | length) worktrees..."
    for p in $paths_to_remove {
        work rm $p --force
    }

    work cache-invalidate
    print -e $"✅ Pruned ($paths_to_remove | length) worktrees."
    { pruned: $paths_to_remove }
}

# Completer: list of local branches that DON'T have a worktree.
# For `work new <name>` autocompletion (so we don't suggest names already used).
def "work _complete-branches-no-wt" []: nothing -> list<string> {
    let info_r = (do { ^git rev-parse --show-toplevel } | complete)
    if $info_r.exit_code != 0 { return [] }
    let root = ($info_r.stdout | str trim)

    let wt_r = (do { ^git -C $root worktree list --porcelain } | complete)
    if $wt_r.exit_code != 0 { return [] }
    let active = (
        $wt_r.stdout
        | lines
        | where ($it | str starts-with "branch ")
        | each { |l| $l | str replace "branch refs/heads/" "" }
    )
    let refs_r = (do { ^git -C $root for-each-ref --format='%(refname:short)' refs/heads/ } | complete)
    if $refs_r.exit_code != 0 { return [] }
    $refs_r.stdout
    | lines
    | where { |b| not ($b in $active) }
}

# Completer: list of branches that DO have a worktree in current repo.
# For `work rm <branch>` autocompletion.
# Bug 4 fix: excludes the main repo's branch (e.g. master) so it doesn't appear in rm picker.
def "work _complete-worktrees" []: nothing -> list<string> {
    # Scan ALL pools (not just current repo) — work rm supports cross-repo removal,
    # and you often run it from a different repo (e.g. bazgroly) than the worktree's.
    work scan-worktrees | get branch | uniq
}
