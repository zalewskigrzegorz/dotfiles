# work.nu — git worktree workflow on herdr.
#
# Each worktree = one herdr workspace (grouped under the source repo, native
# `prefix+shift+g`). This CLI wraps `herdr worktree …` so the same flow works
# from the prompt and keeps Greg's path scheme + commitlint branch naming.
#
#   work [target]     — THE command: picker over branches / PRs / worktrees →
#                       action menu (thin wrapper over the `workctl` binary,
#                       scriptc/workctl.ts). `work new` / `work switch` /
#                       `work pr` are the same thing with a different opening.
#   work ls           — list worktrees of the current repo (nu data)
#   work layout       — apply the claude-tab layout to the current workspace
#   work rm [branch]  — remove worktree + workspace + git branch
#   work pr [number]  — PR command center (defined in workpr.nu — loads after this
#                       file, so it can call the primitives here; the reverse is
#                       impossible, which is why `work pr` does not live here)
#   work prune        — batch-remove merged worktrees
#   work help         — cheatsheet

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

# Scan worktrees ON DISK, cross-repo — so worktrees made by the old setup (or by
# hand) show up, not just ones herdr already opened. Two pools: ours
# (~/Code/tree/wt-<repo>/<branch>) and herdr's native default
# (~/.herdr/worktrees/<repo>/<slug>), where prefix+shift+g puts them.
# Returns records: {repo, root, branch, path, status, head}.
def "work _scan-worktrees" []: nothing -> list<record> {
    let pools = [
        ($env.HOME | path join "Code" "tree" "wt-*")
        ($env.HOME | path join ".herdr" "worktrees" "*")
    ]
    $pools
    | each { |p| glob $"($p)/**/.git" --depth 6 }
    | flatten
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
# Only claude auto-spawns; git/nvim stay on-demand via `lazygit` / `baz` to spare
# CPU. Idempotent — skips if a claude tab exists.
def "work _apply-layout" [workspace_id: string, cwd: path]: nothing -> nothing {
    # Every worktree open/create funnels through here, so this is where we ensure
    # the work-scoped skills (g-pr-review, …) exist in the worktree's .claude/skills.
    # The script no-ops outside the work monorepo, so it's safe on any repo.
    if (which place-work-skills | is-not-empty) {
        do { ^place-work-skills $cwd } | complete | ignore
    }
    # Claude reads disabledMcpServers only from projects[<cwd>] in ~/.claude.json —
    # no global scope — so a fresh worktree re-shows the whole claude.ai connector
    # catalog. Seed it here, before the claude tab below starts a session at $cwd.
    if (which claude-mcp-defaults | is-not-empty) {
        do { ^claude-mcp-defaults $cwd } | complete | ignore
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

# Seed a fresh worktree with untracked env files + node_modules from the parent
# checkout. git worktrees carry only tracked files, so a new tree has no `.env`
# and no deps. We clone them via APFS clonefile (`cp -c`: instant, no extra disk,
# preserves pnpm symlinks) at the same relative paths — handles monorepos (nested
# node_modules / .env) automatically. Uses git's own ignore list so ONLY env +
# node_modules are touched, nothing else. Best-effort: never fails the create.
def "work _seed-untracked" [parent: path, wt_path: path]: nothing -> nothing {
    let r = (do { ^git -C $parent ls-files --others --ignored --exclude-standard --directory } | complete)
    if $r.exit_code != 0 { return }
    let entries = (
        $r.stdout | lines
        | where { |e|
            let base = ($e | str trim --right --char "/" | path basename)
            $base == "node_modules" or $base == ".env" or ($base | str starts-with ".env.")
        }
    )
    if ($entries | is-empty) { return }
    mut copied = 0
    for e in $entries {
        let rel = ($e | str trim --right --char "/")
        let src = ($parent | path join $rel)
        let dst = ($wt_path | path join $rel)
        if not ($src | path exists) { continue }
        if ($dst | path exists) { continue }
        mkdir ($dst | path dirname)
        let c = (do { ^cp -cR $src $dst } | complete)
        if $c.exit_code != 0 { do { ^cp -R $src $dst } | complete | ignore }
        $copied += 1
    }
    if $copied > 0 { print -e $"🌱 seeded ($copied) untracked path\(s\) \(env + node_modules)" }
}

# `work new` is a THIN WRAPPER over `workctl` (scriptc/workctl.ts).
#
# The four prompts this def used to fire in sequence — fzf branch picker, the
# commitlint type menu, "branch exists [c/n/a]", and full/light/diff — are two
# screens there: pick the target (a branch, a PR, a worktree, or "create X from
# origin/main | from HEAD"), then pick what to do with it from the same action
# registry `work pr` had. Same flow from herdr, gh-dash and lazygit, which
# cannot see this autoload dir at all. `workctl --help` lists the flags.
def --wrapped "work new" [...rest]: nothing -> nothing {
    ^workctl ...$rest
}

# `work pr` lives in workpr.nu — autoload visibility is one-directional (a file
# can only call defs from files that loaded BEFORE it), and the PR command center
# needs the primitives above, so it has to be defined in the later-loading file.
# Its worktree/fork/seed/layout logic is the old body of this def, lifted into
# `work-pr _worktree`.

# List ALL worktrees on disk (cross-repo). nu data; `| to json` for scripting.
def "work ls" []: nothing -> list<record> {
    work _scan-worktrees | select repo branch status head path
}

# `work switch` is the same picker with the other repos' worktrees folded in —
# switching to a worktree and checking one out were never different actions, only
# different rows.
def "work switch" []: nothing -> nothing {
    ^workctl --all
}

def "work sw" []: nothing -> nothing { work switch }

# Remove worktree + workspace + git branch.
def "work rm" [
    branch?: string@"work _complete-worktrees"
    --self (-s)   # remove the worktree you are standing in (no picker)
    --force
    --keep-branch
]: nothing -> record {
    work deps-preflight
    let wts = (work _scan-worktrees)

    # `-s` removes the worktree cwd sits inside — the common "kill this one" case,
    # kept explicit so a bare `work rm` never nukes the current tree by surprise.
    let here = (pwd | path expand)
    let cur = ($wts | where {|w| let p = ($w.path | path expand); ($here == $p) or ($here | str starts-with $"($p)/") } | get -o 0)

    let target = (
        if ($branch | is-not-empty) {
            let m = ($wts | where branch == $branch)
            if ($m | is-empty) { error make { msg: $"No worktree for branch '($branch)'." } }
            if ($m | length) > 1 {
                error make { msg: $"Ambiguous '($branch)' — in: (($m | get repo) | str join ', '). Use the picker (`work rm`)." }
            }
            ($m | first)
        } else if $self {
            if ($cur == null) { error make { msg: "Not inside a worktree — `-s` has nothing to remove." } }
            print -e $"🎯 current worktree: ($cur.branch) \(($cur.repo)\)"
            $cur
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
    # Removing the worktree you were standing in leaves the shell in a deleted dir.
    # herdr closes+refocuses its own workspaces; a plain-git worktree does not, so
    # nudge the caller out (a def cannot change the caller's cwd).
    if (($here == ($target.path | path expand)) or ($here | str starts-with $"(($target.path | path expand))/")) and ($ws | is-empty) {
        print -e $"↩️  you were inside it — `cd ($target.root)`"
    }
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

# Recompute the correct label for the CURRENT herdr workspace and rename it back.
# herdr sometimes auto-relabels a workspace from the branch/tab (e.g. main → a
# stray tab name); this restores the label `work new`/`work switch` would give it.
def "work reset" []: nothing -> any {
    work deps-preflight
    let info = (work repo-info)
    let wt_path = (if $info.is_worktree { $info.worktree_path } else { $info.root })
    let ws = (work _herdr-ws-for $info.root $wt_path)
    if ($ws | is-empty) {
        print -e $"No herdr workspace maps to ($wt_path). Open it with `work switch` first."
        return
    }
    let branch = (do { ^git -C $wt_path branch --show-current } | complete | get stdout | str trim)
    let label = (work _label $info.name $branch)
    let old = (try { (do { ^herdr workspace get $ws } | complete).stdout | from json | get -o result.workspace.label | default "" } catch { "" })
    let r = (do { ^herdr workspace rename $ws $label } | complete)
    if $r.exit_code != 0 { error make { msg: $"herdr workspace rename failed: ($r.stderr)" } }
    print -e $"✅ ($old) → ($label)"
    { workspace_id: $ws, old: $old, new: $label }
}

# Open nvim in this repo's bazgroly dir.
def baz []: nothing -> nothing {
    let dir = (work bazgroly-path)
    if not ($dir | path exists) { mkdir $dir }
    ^nvim $dir
}

# Bare `work` IS the picker — `work`, `work new`, `work switch`, `work pr` are
# one command with four openings. A positional target (branch name, PR number)
# skips straight to that target's action menu.
def --wrapped work [--help (-h), ...rest]: nothing -> nothing {
    if $help { work help; return }
    ^workctl ...$rest
}

# What bare `work` used to do: apply the layout (claude tab) to the current
# herdr workspace.
def "work layout" []: nothing -> nothing {
    let ws = ($env.HERDR_WORKSPACE_ID? | default "")
    if ($ws | is-empty) { print -e "not inside a herdr workspace"; return }
    work _apply-layout $ws $env.PWD
    print -e "layout applied (claude tab)"
}

# Cheatsheet.
def "work help" []: nothing -> nothing {
    print "📖 Work — git worktree workflow on herdr"
    print ""
    print "WORKFLOW"
    print "  work             →  wybierz cel (branch / PR / worktree / nowy z maina lub HEAD)"
    print "                   →  wybierz akcję (TAB = kilka)  →  menu wraca, aż Esc"
    print "  work <branch>    work <#pr>    prosto do menu akcji tego celu"
    print ""
    print "MENU AKCJI (rejestr work pr + worktree)"
    print "  → sugestie na górze wg stanu PR: resolve / fix CI / logs / update / merge …"
    print "  🌱 worktree + .env/node_modules   👓 goły   🚀 secrets.sh && install (własny tab)"
    print "  👀💬🔧🤖📣 agenci (claude z briefem)   🏷 labele   🥞 stack   📄 diff   🗑 rm   🌐 web"
    print "  te same wejścia: prefix+shift+g / +o (herdr) · T i w (gh-dash) · w (lazygit)"
    print ""
    print "KOMENDY"
    print "  work [target]      picker → menu akcji (--all: worktree z innych repo)"
    print "  work new / switch / pr [n]   to samo, inne otwarcie (kompatybilność)"
    print "  work ls            lista worktree (nu data; `| to json`)"
    print "  work layout        tab claude w bieżącym workspace (dawne gołe `work`)"
    print "  work rm [branch]   usuń worktree + workspace + branch (--force / --keep-branch)"
    print "  work prune         batch usuń merged + clean (--dry-run)"
    print "  work reset         przywróć poprawny label bieżącego workspace herdr"
    print "  baz                nvim w bazgroly tego repo"
    print ""
    print "NAWIGACJA herdr:  prefix=ctrl+space · prefix w workspace · prefix g goto · prefix b sidebar · prefix ? help"
}

# Completer: branches that have a worktree on disk (for `work rm`).
def "work _complete-worktrees" []: nothing -> list<string> {
    work _scan-worktrees | get branch | uniq
}
