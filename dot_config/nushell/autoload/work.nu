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
