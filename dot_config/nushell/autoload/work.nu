# work.nu — git worktree workflow on herdr (replaces the tmux+sesh version).
#
# Each worktree = one herdr workspace (grouped under the source repo, native
# `prefix+shift+g`). This CLI wraps `herdr worktree …` so the same flow works
# from the prompt and keeps Greg's path scheme + commitlint branch naming.
#
#   work new <name>   — create worktree + herdr workspace, focus it
#   work ls           — list worktrees of the current repo (nu data)
#   work switch (sw)   — picker over worktrees → focus that workspace
#   work rm [branch]  — remove worktree + workspace + git branch
#   work pr [number]  — open a GitHub PR in a worktree
#   work prune        — batch-remove merged worktrees
#   work help         — cheatsheet
#
# Old tmux version: `git -C ~/Code/dotfiles show pre-herdr:dot_config/nushell/autoload/work.nu`.

# Emoji-prefix mapping for worktree workspace labels (commitlint types).
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

# Normalize branch name to a short label suffix.
#   "feat/billing-page" -> "✨billing-page"   "wip/x" -> "wip-x"   "experimental" -> "experimental"
def "work normalize-label" [branch: string]: nothing -> string {
    if not ($branch | str contains "/") { return $branch }
    let parts = ($branch | split row --number 2 "/")
    let emoji = ($WORK_PREFIX_EMOJI | get --optional $parts.0)
    if ($emoji | is-not-empty) { $"($emoji)($parts.1)" } else { $"($parts.0)-($parts.1)" }
}

# herdr workspace label for a worktree — just the branch (emoji type prefix kept).
# herdr already groups the worktree under its source repo in the sidebar, so the
# repo name in the label is redundant.
def "work _label" [repo: string, branch: string]: nothing -> string {
    work normalize-label $branch
}

const WORK_CONVENTIONAL_DEFAULTS = [
    "build" "chore" "ci" "docs" "feat" "fix"
    "perf" "refactor" "revert" "style" "test"
]

# Load allowed commit type prefixes from a repo's commitlint config.
def "work load-commitlint-types" [
    repo_path?: path
]: nothing -> list<string> {
    let repo_path = (if ($repo_path | is-empty) { $env.PWD | path expand } else { $repo_path })
    let candidates = [
        ($repo_path | path join "commitlint.config.js")
        ($repo_path | path join "commitlint.config.cjs")
        ($repo_path | path join "commitlint.config.mjs")
        ($repo_path | path join "package.json")
    ]
    let config_file = ($candidates | where { |p| $p | path exists } | first)
    if ($config_file | is-empty) { return [] }
    let content = (open --raw $config_file)

    if ($config_file | str ends-with "package.json") {
        let pkg = (try { open $config_file } catch { return [] })
        let cl = ($pkg | get -o "commitlint")
        if ($cl == null) { return [] }
        let type_enum = ($cl | get -o "rules" | default {} | get -o "type-enum")
        if ($type_enum != null and ($type_enum | length) >= 3) { return ($type_enum | get 2) }
        let extends_list = ($cl | get -o "extends" | default [])
        if ($extends_list | any { |e| $e | str contains "config-conventional" }) {
            return $WORK_CONVENTIONAL_DEFAULTS
        }
        return []
    }

    let match = (
        $content
        | parse --regex `(?s)["']type-enum["']\s*:\s*\[\s*\d+\s*,\s*["'][^"']+["']\s*,\s*\[(.*?)\]`
    )
    if ($match | is-empty) {
        if ($content | str contains "config-conventional") { return $WORK_CONVENTIONAL_DEFAULTS }
        print $"⚠️  ($config_file) — type-enum niewykryty. Użyj --type aby wymusić prefix."
        return []
    }
    $match.capture0.0 | parse --regex `["']([^"']+)["']` | get capture0
}

# Resolve repo info from parent or worktree.
def "work repo-info" []: nothing -> record {
    let toplevel = (do { ^git rev-parse --show-toplevel } | complete)
    if $toplevel.exit_code != 0 { error make { msg: "Not inside a git repository." } }
    let worktree_path = ($toplevel.stdout | str trim)

    let common_dir_r = (do { ^git rev-parse --path-format=absolute --git-common-dir } | complete)
    if $common_dir_r.exit_code != 0 { error make { msg: "Failed to resolve git common dir" } }
    let common_dir_raw = ($common_dir_r.stdout | str trim)
    let parent_root = (
        if ($common_dir_raw | str ends-with "/.git") {
            $common_dir_raw | str substring 0..(($common_dir_raw | str length) - 6)
        } else { $common_dir_raw | path dirname }
    )
    let name = ($parent_root | path basename)

    let git_dir_r = (do { ^git rev-parse --git-dir } | complete)
    let git_dir = ($git_dir_r.stdout | str trim)
    let is_worktree = ($git_dir != ".git" and $git_dir != $common_dir_raw)

    let head_ref = (do { ^git symbolic-ref refs/remotes/origin/HEAD } | complete)
    let default_branch = (
        if $head_ref.exit_code == 0 {
            $head_ref.stdout | str trim | str replace "refs/remotes/origin/" ""
        } else { "master" }
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

# Worktree path: ~/Code/tree/wt-<repo>/<branch>.
def "work worktree-path" [repo: string, branch: string]: nothing -> path {
    $env.HOME | path join "Code" "tree" $"wt-($repo)" $branch
}

# bazgroly dir for the current repo.
def "work bazgroly-path" []: nothing -> path {
    let in_repo = ((do { ^git rev-parse --show-toplevel } | complete | get exit_code) == 0)
    let name = (if $in_repo { (work repo-info | get name) } else { "scratch" })
    $env.HOME | path join "Code" "personal" "bazgroly" $name
}

# Preflight: git always; gh/fzf only where used.
def "work deps-preflight" []: nothing -> nothing {
    if (which git | is-empty) { error make { msg: "git required." } }
    if (which herdr | is-empty) { error make { msg: "herdr required: brew install herdr" } }
}

# Scan worktrees ON DISK (~/Code/tree/wt-*/), cross-repo — so worktrees made by
# the old setup (or by hand) show up, not just ones herdr already opened.
# Returns records: {repo, root, branch, path, status, head}.
def "work _scan-worktrees" []: nothing -> list<record> {
    let pool = ($env.HOME | path join "Code" "tree")
    if not ($pool | path exists) { return [] }
    glob $"($pool)/wt-*/**/.git" --depth 6
    | par-each { |m|
        let wt = ($m | path dirname)
        let cd_r = (do { ^git -C $wt rev-parse --path-format=absolute --git-common-dir } | complete)
        if $cd_r.exit_code != 0 { return null }
        let cd = ($cd_r.stdout | str trim)
        let root = (if ($cd | str ends-with "/.git") { $cd | str substring 0..(($cd | str length) - 6) } else { $cd | path dirname })
        let br = (do { ^git -C $wt branch --show-current } | complete | get stdout | str trim)
        let st = (do { ^git -C $wt status --porcelain } | complete | get stdout | str trim)
        let hd = (do { ^git -C $wt rev-parse HEAD } | complete | get stdout | str trim)
        {
            repo: ($root | path basename)
            root: $root
            branch: (if ($br | is-empty) { "(detached)" } else { $br })
            path: $wt
            status: (if ($st | is-empty) { "clean" } else { "dirty" })
            head: ($hd | str substring 0..6)
        }
    }
    | where { |it| $it != null }
}

# herdr workspace_id for an open worktree path (empty if not open), via herdr.
def "work _herdr-ws-for" [repo_root: path, wt_path: path]: nothing -> string {
    let r = (do { ^herdr worktree list --cwd $repo_root --json } | complete)
    if $r.exit_code != 0 { return "" }
    let wts = (try { $r.stdout | from json | get -o result.worktrees | default [] } catch { [] })
    let want = ($wt_path | path expand)
    let m = ($wts | where { |w| ($w.path | path expand) == $want })
    if ($m | is-empty) { "" } else { ($m | first | get -o open_workspace_id | default "") }
}

# Auto-layout for a worktree workspace: ensure a "claude" tab running claude.
# Matches the old tmux layout (only claude auto-spawned; git/nvim stay on-demand
# via `lazygit` / `baz` to spare CPU). Idempotent — skips if a claude tab exists.
def "work _apply-layout" [workspace_id: string, cwd: path]: nothing -> nothing {
    # Every worktree open/create funnels through here, so this is where we ensure
    # the work-scoped skills (g-pr-review, …) exist in the worktree's .claude/skills.
    # The script no-ops outside the work monorepo, so it's safe on any repo.
    if (which place-work-skills | is-not-empty) {
        do { ^place-work-skills $cwd } | complete | ignore
    }
    if ($workspace_id | is-empty) { return }
    let tabs = (try { (do { ^herdr tab list --workspace $workspace_id } | complete).stdout | from json | get -o result.tabs | default [] } catch { [] })
    # Name the bare-numbered terminal tab with a nerd-font terminal icon (nf-fa-terminal).
    for t in $tabs {
        if (($t.label? | default "") =~ '^[0-9]+$') {
            do { ^herdr tab rename $t.tab_id $"\u{f120}  nu" } | complete | ignore
        }
    }
    # Ensure a claude tab (only one auto-spawned; git/nvim stay on-demand).
    if ($tabs | any { |t| ($t.label? | default "" | str contains "claude") }) { return }
    let r = (do { ^herdr tab create --workspace $workspace_id --cwd $cwd --label $"\u{f06a9}  claude" --no-focus } | complete)
    let pane = (try { $r.stdout | from json | get -o result.root_pane.pane_id } catch { "" })
    if ($pane | is-not-empty) { do { ^herdr pane run $pane "claude" } | complete | ignore }
}

# Path where a branch is already checked out (any worktree), "" if none.
# Git refuses to check a branch out twice, so create must defer to open when set.
def "work _checkout-path" [repo_root: path, branch: string]: nothing -> string {
    let r = (do { ^git -C $repo_root worktree list --porcelain } | complete)
    if $r.exit_code != 0 { return "" }
    mut path = ""
    mut found = ""
    for line in ($r.stdout | lines) {
        if ($line | str starts-with "worktree ") { $path = ($line | str replace "worktree " "") }
        if ($line | str starts-with "branch ") {
            if (($line | str replace "branch refs/heads/" "") == $branch) { $found = $path }
        }
    }
    $found
}

# Create a new worktree + herdr workspace, focus it.
def "work new" [
    name: string@"work _complete-branches-no-wt" = ""
    --from: string = ""
    --type: string = ""
    --pick-from
    --no-prefix
    --no-focus
]: nothing -> any {
    work deps-preflight
    let info = (work repo-info)
    let repo = $info.name
    let parent = $info.root
    let default_branch = $info.default_branch

    # --- Branch name (picker when empty) ---
    mut effective_name = $name
    if ($name | is-empty) {
        if (which fzf | is-empty) { error make { msg: "Pass a branch name (fzf not installed for picker)." } }
        let local_r = (do { ^git -C $parent for-each-ref --format='%(refname:short)' refs/heads/ } | complete)
        let local_b = (if $local_r.exit_code == 0 { $local_r.stdout | lines } else { [] })
        let remote_r = (do { ^git -C $parent for-each-ref --format='%(refname:short)' refs/remotes/origin/ } | complete)
        let remote_b = (if $remote_r.exit_code == 0 { $remote_r.stdout | lines | where { |b| $b != "HEAD" } } else { [] })
        let cands = ($local_b ++ $remote_b ++ ["+ Create new branch..."])
        let picked = ($cands | str join "\n" | ^fzf --prompt "Branch: " | str trim)
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
    let input_name = $effective_name

    # --- Base ref ---
    let base_ref = (
        if $pick_from {
            if (which fzf | is-empty) { error make { msg: "--pick-from needs fzf." } }
            let cands_r = (do { ^git -C $parent for-each-ref --format='%(refname:short)' refs/remotes/origin/ refs/heads/ } | complete)
            let candidates = (if $cands_r.exit_code == 0 { $cands_r.stdout | lines } else { [] })
            let picked = ($candidates | str join "\n" | ^fzf --prompt "Base ref: " | str trim)
            if ($picked | is-empty) { error make { msg: "No base ref selected." } }
            $picked
        } else if ($from | is-empty) { $"origin/($default_branch)" } else { $from }
    )

    # --- Commitlint type enforcement ---
    let allowed_types = (work load-commitlint-types $parent)
    let has_enforcement = (not ($allowed_types | is-empty))
    let has_slash = ($input_name | str contains "/")
    mut final_name = $input_name

    if $has_enforcement and not $has_slash and not $no_prefix {
        if not ($type | is-empty) {
            if not ($type in $allowed_types) {
                error make { msg: $"Type '($type)' not allowed: ($allowed_types | str join ', ')" }
            }
            $final_name = $"($type)/($input_name)"
        } else {
            print $"\n⚠️  Repo '($repo)' uses commitlint — choose branch type:"
            for row in ($allowed_types | enumerate) {
                let emoji = ($WORK_PREFIX_EMOJI | get --optional $row.item | default "  ")
                let desc = ($WORK_PREFIX_DESC | get --optional $row.item | default "")
                print $"  [($row.index + 1)] ($emoji) ($row.item)      ($desc)"
            }
            print "  [a] abort"
            let choice = (input "Choice: ")
            if $choice == "a" or ($choice | is-empty) { error make { msg: "Aborted." } }
            let idx = (try { ($choice | into int) - 1 } catch { error make { msg: $"Invalid choice: ($choice)" } })
            if $idx < 0 or $idx >= ($allowed_types | length) { error make { msg: "Out of range." } }
            $final_name = $"(($allowed_types | get $idx))/($input_name)"
            print $"→ branch: ($final_name)"
        }
    }
    let branch_name = $final_name
    let wt_path = (work worktree-path $repo $branch_name)
    let label = (work _label $repo $branch_name)
    let focus_flag = (if $no_focus { "--no-focus" } else { "--focus" })

    # Branch already checked out anywhere on disk → open that checkout (git won't
    # check a branch out twice), don't try to re-create at the canonical path.
    let existing_co = (work _checkout-path $parent $branch_name)
    if ($existing_co | is-not-empty) {
        print -e $"Worktree exists, opening ($label)"
        let r = (do { ^herdr worktree open --cwd $parent --path $existing_co --label $label $focus_flag --json } | complete)
        if $r.exit_code != 0 { error make { msg: $"herdr worktree open failed: ($r.stderr)" } }
        let ws = (try { $r.stdout | from json | get -o result.workspace.workspace_id } catch { "" })
        work _apply-layout $ws $existing_co
        return { repo: $repo, branch: $branch_name, path: $existing_co, label: $label, created: false }
    }

    # Fresh fetch (best-effort).
    let fetch_ref = ($base_ref | str replace "origin/" "")
    do { ^git -C $parent fetch origin $fetch_ref } | complete | ignore

    # Collision check.
    let exists_local = ((do { ^git -C $parent rev-parse --verify --quiet $"refs/heads/($branch_name)" } | complete | get exit_code) == 0)
    let exists_remote = ((do { ^git -C $parent rev-parse --verify --quiet $"refs/remotes/origin/($branch_name)" } | complete | get exit_code) == 0)
    mut checkout_existing = false
    if ($exists_local or $exists_remote) {
        print $"\n⚠️  Branch '($branch_name)' already exists — local=($exists_local) remote=($exists_remote)."
        print "  [c] checkout existing into worktree   [n] new name   [a] abort"
        let choice = (input "Choice [c/n/a]: ")
        match $choice {
            "c" => { $checkout_existing = true }
            "n" => {
                let nn = (input "New branch name: ")
                if ($nn | is-empty) { error make { msg: "Aborted." } }
                return (work new $nn --from $base_ref)
            }
            _ => { error make { msg: "Aborted." } }
        }
    }

    # herdr creates the checkout at --path + opens it as a workspace.
    # Existing branch → omit --base (herdr checks it out); new branch → --base.
    let r = (
        if $checkout_existing {
            do { ^herdr worktree create --cwd $parent --branch $branch_name --path $wt_path --label $label $focus_flag --json } | complete
        } else {
            do { ^herdr worktree create --cwd $parent --branch $branch_name --base $base_ref --path $wt_path --label $label $focus_flag --json } | complete
        }
    )
    if $r.exit_code != 0 { error make { msg: $"herdr worktree create failed: ($r.stderr)" } }
    let ws = (try { $r.stdout | from json | get -o result.workspace.workspace_id } catch { "" })
    work _apply-layout $ws $wt_path

    print -e $"✅ ($branch_name) → ($wt_path)"
    { repo: $repo, branch: $branch_name, path: $wt_path, label: $label, workspace_id: $ws, base: $base_ref, created: true }
}

# Open a GitHub PR in a new worktree workspace.
def "work pr" [
    number?: int
    --no-focus
]: nothing -> any {
    work deps-preflight
    if (which gh | is-empty) { error make { msg: "gh CLI required: brew install gh" } }
    let info = (work repo-info)
    let parent = $info.root
    let focus_flag = (if $no_focus { "--no-focus" } else { "--focus" })

    let pr_num = (
        if ($number | is-not-empty) { $number } else {
            if (which fzf | is-empty) { error make { msg: "Pass a PR number (fzf not installed)." } }
            let rows = (^gh pr list --limit 50 --json number,title,headRefName --jq '.[] | "\(.number)\t\(.title)\t\(.headRefName)"')
            if ($rows | str trim | is-empty) { error make { msg: "No open PRs." } }
            let picked = ($rows | ^fzf --delimiter "\t" --with-nth=1,2,3 --prompt "PR: " | str trim)
            if ($picked | is-empty) { error make { msg: "No PR selected." } }
            ($picked | split row "\t" | first | into int)
        }
    )

    let pr_meta_r = (do { ^gh pr view $pr_num --json headRefName,baseRefName,isCrossRepository } | complete)
    if $pr_meta_r.exit_code != 0 { error make { msg: $"Cannot resolve PR #($pr_num): ($pr_meta_r.stderr)" } }
    let pr_meta = ($pr_meta_r.stdout | from json)
    let head_branch = $pr_meta.headRefName
    if ($head_branch | is-empty) { error make { msg: $"PR #($pr_num) has no head branch." } }
    let is_fork = $pr_meta.isCrossRepository
    let base = $"origin/($pr_meta.baseRefName)"
    let wt_path = (work worktree-path $info.name $head_branch)
    let label = (work _label $info.name $head_branch)

    let existing_co = (work _checkout-path $parent $head_branch)
    if ($existing_co | is-not-empty) {
        print -e $"Worktree for PR #($pr_num) exists, opening."
        let r = (do { ^herdr worktree open --cwd $parent --path $existing_co --label $label $focus_flag --json } | complete)
        let ws = (try { $r.stdout | from json | get -o result.workspace.workspace_id } catch { "" })
        work _apply-layout $ws $existing_co
        return { repo: $info.name, pr: $pr_num, branch: $head_branch, path: $existing_co, created: false }
    }

    if $is_fork {
        # Fork: git creates the detached checkout + gh sets up the fork remote, then herdr opens it.
        let a = (do { ^git -C $parent worktree add --detach $wt_path } | complete)
        if $a.exit_code != 0 { error make { msg: $"worktree add failed: ($a.stderr)" } }
        let co = (do { ^bash -c $"cd '($wt_path)' && gh pr checkout ($pr_num)" } | complete)
        if $co.exit_code != 0 {
            ^git -C $parent worktree remove $wt_path --force
            error make { msg: $"gh pr checkout #($pr_num) failed: ($co.stderr)" }
        }
        let cur = (do { ^git -C $wt_path branch --show-current } | complete | get stdout | str trim)
        if ($cur | is-empty) { ^git -C $wt_path checkout -B $head_branch | ignore }
        do { ^herdr worktree open --cwd $parent --path $wt_path --label $label $focus_flag --json } | complete | ignore
    } else {
        # Same-repo: herdr creates the checkout tracking the PR branch.
        do { ^git -C $parent fetch origin $head_branch } | complete | ignore
        let r = (do { ^herdr worktree create --cwd $parent --branch $head_branch --base $"origin/($head_branch)" --path $wt_path --label $label $focus_flag --json } | complete)
        if $r.exit_code != 0 { error make { msg: $"herdr worktree create failed: ($r.stderr)" } }
    }

    work _apply-layout (work _herdr-ws-for $parent $wt_path) $wt_path
    print -e $"✅ PR #($pr_num) → ($head_branch)"
    { repo: $info.name, pr: $pr_num, branch: $head_branch, path: $wt_path, base: $base, created: true }
}

# List ALL worktrees on disk (cross-repo). nu data; `| to json` for scripting.
def "work ls" []: nothing -> list<record> {
    work _scan-worktrees | select repo branch status head path
}

# Picker over disk worktrees → open/focus that workspace in herdr.
def "work switch" []: nothing -> nothing {
    let wts = (work _scan-worktrees)
    if ($wts | is-empty) {
        print "No worktrees on disk. Use `work new <branch>` to create one."
        return
    }
    if (which fzf | is-empty) { error make { msg: "fzf not installed for the picker." } }
    # line: repo\tbranch\tstatus\tpath\troot  (display first 3)
    let picked = (
        $wts | each { |w| $"($w.repo)\t($w.branch)\t($w.status)\t($w.path)\t($w.root)" }
        | str join "\n"
        | ^fzf --delimiter "\t" --with-nth=1,2,3 --prompt "Switch to worktree: "
        | str trim
    )
    if ($picked | is-empty) { return }
    let f = ($picked | split row "\t")
    let label = (work _label ($f | get 0) ($f | get 1))
    let r = (do { ^herdr worktree open --cwd ($f | get 4) --path ($f | get 3) --label $label --focus --json } | complete)
    if $r.exit_code != 0 { error make { msg: $"herdr worktree open failed: ($r.stderr)" } }
    let ws = (try { $r.stdout | from json | get -o result.workspace.workspace_id } catch { "" })
    work _apply-layout $ws ($f | get 3)
}

def "work sw" []: nothing -> nothing { work switch }

# Remove worktree + workspace + git branch.
def "work rm" [
    branch?: string@"work _complete-worktrees"
    --force
    --keep-branch
]: nothing -> record {
    work deps-preflight
    let wts = (work _scan-worktrees)

    let target = (
        if ($branch | is-not-empty) {
            let m = ($wts | where branch == $branch)
            if ($m | is-empty) { error make { msg: $"No worktree for branch '($branch)'." } }
            if ($m | length) > 1 {
                error make { msg: $"Ambiguous '($branch)' — in: (($m | get repo) | str join ', '). Use the picker (`work rm`)." }
            }
            ($m | first)
        } else if (which fzf | is-not-empty) {
            if ($wts | is-empty) { error make { msg: "No worktrees." } }
            let picked = ($wts | each { |w| $"($w.repo)\t($w.branch)\t($w.status)\t($w.path)" } | str join "\n" | ^fzf --delimiter "\t" --with-nth=1,2,3 --prompt "Remove worktree: " | str trim)
            if ($picked | is-empty) { error make { msg: "Nothing picked." } }
            let p = ($picked | split row "\t" | get 3)
            ($wts | where path == $p | first)
        } else { error make { msg: "Pass a branch name (fzf not installed)." } }
    )

    if $target.status == "dirty" and (not $force) {
        let yn = (input $"⚠️  ($target.branch) has uncommitted changes. Force remove? [y/N]: ")
        if $yn != "y" { error make { msg: "Aborted." } }
    }

    # If the worktree is open as a herdr workspace, herdr removes checkout + closes it;
    # otherwise plain git removes the checkout. git keeps the branch either way.
    let ws = (work _herdr-ws-for $target.root $target.path)
    if ($ws | is-not-empty) {
        let r = (do { ^herdr worktree remove --workspace $ws --force } | complete)
        if $r.exit_code != 0 { error make { msg: $"herdr worktree remove failed: ($r.stderr)" } }
    } else {
        ^git -C $target.root worktree remove $target.path --force
    }
    if not $keep_branch {
        let r = (do { ^git -C $target.root branch -d $target.branch } | complete)
        if $r.exit_code != 0 {
            print -e $"⚠️  Branch ($target.branch) not fully merged — `git branch -D ($target.branch)` to force."
        }
    }
    print -e $"✅ Removed: ($target.branch)"
    { removed: $target.branch, path: $target.path }
}

# Batch-remove merged + clean worktrees (cross-repo; each checked vs its own default).
def "work prune" [--dry-run]: nothing -> any {
    work deps-preflight
    let candidates = (
        work _scan-worktrees
        | where status == "clean"
        | each { |w|
            let head_ref = (do { ^git -C $w.root symbolic-ref refs/remotes/origin/HEAD } | complete)
            let def = (if $head_ref.exit_code == 0 { $head_ref.stdout | str trim | str replace "refs/remotes/origin/" "" } else { "master" })
            let merged_r = (do { ^git -C $w.root branch --merged $def } | complete)
            let merged = (if $merged_r.exit_code == 0 { $merged_r.stdout | lines | each { |l| $l | str trim | str replace "* " "" } } else { [] })
            if ($w.branch in $merged) { $w } else { null }
        }
        | where { |it| $it != null }
    )
    if ($candidates | is-empty) { print -e "Nothing to prune (no merged + clean worktrees)."; return [] }
    if $dry_run { return ($candidates | select repo branch path) }

    let picked = (
        if (which fzf | is-not-empty) {
            $candidates | each { |c| $"($c.repo)/($c.branch)\t($c.path)" } | str join "\n"
            | ^fzf --multi --prompt "Prune (Tab=multi): " --delimiter "\t" --with-nth=1 | lines
        } else { $candidates | each { |c| $"($c.repo)/($c.branch)\t($c.path)" } }
    )
    if ($picked | is-empty) { return [] }
    for line in $picked {
        let p = ($line | split row "\t" | get 1)
        let w = ($candidates | where path == $p | first)
        work rm $w.branch --force
    }
    print -e $"✅ Pruned ($picked | length) worktrees."
    { pruned: ($picked | each { |l| $l | split row "\t" | first }) }
}

# Open nvim in this repo's bazgroly dir.
def baz []: nothing -> nothing {
    let dir = (work bazgroly-path)
    if not ($dir | path exists) { mkdir $dir }
    ^nvim $dir
}

# Bare `work` — apply the layout (claude tab) to the current herdr workspace.
# Outside herdr, or with --help, show the cheatsheet.
def work [--help (-h)]: nothing -> nothing {
    if $help { work help; return }
    let ws = ($env.HERDR_WORKSPACE_ID? | default "")
    if ($ws | is-empty) { work help; return }
    work _apply-layout $ws $env.PWD
    print -e "layout applied (claude tab)"
}

# Cheatsheet.
def "work help" []: nothing -> nothing {
    print "📖 Work — git worktree workflow on herdr"
    print ""
    print "WORKFLOW"
    print "  work new <name>  →  praca  →  commit / push  →  work rm <name>"
    print "  przełącz:  work switch   (albo prefix+w / prefix+g / sidebar)"
    print "  PR:        work pr <n>"
    print ""
    print "KOMENDY"
    print "  work new [name]    worktree + workspace (picker / <name> / --from / --type / --no-prefix)"
    print "  work pr [number]   otwórz PR w worktree (gh pr checkout)"
    print "  work ls            lista worktree (nu data; `| to json`)"
    print "  work switch (sw)   picker → focus workspace"
    print "  work rm [branch]   usuń worktree + workspace + branch (--force / --keep-branch)"
    print "  work prune         batch usuń merged + clean (--dry-run)"
    print "  baz                nvim w bazgroly tego repo"
    print ""
    print "NAWIGACJA herdr:  prefix=ctrl+space · prefix w workspace · prefix g goto · prefix b sidebar · prefix ? help"
}

# Completer: local branches without a worktree (for `work new`).
def "work _complete-branches-no-wt" []: nothing -> list<string> {
    let root_r = (do { ^git rev-parse --show-toplevel } | complete)
    if $root_r.exit_code != 0 { return [] }
    let root = ($root_r.stdout | str trim)
    let wt_r = (do { ^git -C $root worktree list --porcelain } | complete)
    let active = (
        if $wt_r.exit_code == 0 {
            $wt_r.stdout | lines | where ($it | str starts-with "branch ")
            | each { |l| $l | str replace "branch refs/heads/" "" }
        } else { [] }
    )
    let refs_r = (do { ^git -C $root for-each-ref --format='%(refname:short)' refs/heads/ } | complete)
    if $refs_r.exit_code != 0 { return [] }
    $refs_r.stdout | lines | where { |b| not ($b in $active) }
}

# Completer: branches that have a worktree on disk (for `work rm`).
def "work _complete-worktrees" []: nothing -> list<string> {
    work _scan-worktrees | get branch | uniq
}
