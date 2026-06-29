# herdr TUI tab wrappers — herdr replacement for the old tmux window wrappers.
# When inside herdr, intercept common TUI commands: rename the CURRENT tab to a
# nerd-font icon + name for the duration of the TUI, then restore the tab's
# previous label on exit (works on ctrl-c / error too). Outside herdr, pass
# through to the underlying binary unchanged.
#
# File name prefix `zz-` ensures this autoload runs AFTER `vim.nu` so these defs
# shadow the `alias vim = nvim` / `alias vi = nvim` declared there. `lg` (alias →
# lazygit) and `dash` (alias → gh-dash) flow through these wrappers too.
#
# Use \u{xxxx} escapes for icons so codepoints survive edits (literal glyphs in
# source have been silently stripped before).

# Shared helper. Renames the caller's herdr tab to `name`, runs `cmd ...args` in
# the current pane, then restores the tab's original label. Outside herdr
# (HERDR_TAB_ID unset) just runs the command.
def --wrapped _herdr_tui [
    name: string
    ...cmd_and_args  # first element is the executable, rest are args
] {
    let cmd = ($cmd_and_args | first)
    let rest = ($cmd_and_args | skip 1)
    let tab = ($env.HERDR_TAB_ID? | default "")

    if ($tab | is-empty) {
        run-external $cmd ...$rest
        return
    }

    # capture the tab's current label so we can put it back afterwards
    let prev = (
        try {
            (do { ^herdr tab get $tab } | complete).stdout
            | from json | get -o result.tab.label | default ""
        } catch { "" }
    )

    do { ^herdr tab rename $tab $name } | complete | ignore
    try { run-external $cmd ...$rest }
    if ($prev | is-not-empty) {
        do { ^herdr tab rename $tab $prev } | complete | ignore
    }
}

# Editors — nf-custom-vim (U+E62B)
def --wrapped nvim [...args] { _herdr_tui $"\u{e62b}  nvim" "nvim" ...$args }
def --wrapped vim  [...args] { _herdr_tui $"\u{e62b}  nvim" "nvim" ...$args }
def --wrapped vi   [...args] { _herdr_tui $"\u{e62b}  nvim" "nvim" ...$args }

# lazygit — nf-dev-git (U+E725). `lg` alias expands to lazygit → hits this def.
def --wrapped lazygit [...args] { _herdr_tui $"\u{e725}  git" "lazygit" ...$args }

# hunk — nf-md-source_branch_check (U+F440)
def --wrapped hunk [...args] { _herdr_tui $"\u{f440}  hunk" "hunk" ...$args }

# GitHub dashboard (gh dash extension) — nf-md-github (U+F0865)
def --wrapped gh-dash [...args] { _herdr_tui $"\u{f0865}  gh-dash" "gh" "dash" ...$args }

# lazydocker — nf-md-docker (U+F0868)
def --wrapped lazydocker [...args] { _herdr_tui $"\u{f0868}  docker" "lazydocker" ...$args }

# btop — nf-md-chart_areaspline (U+F0E4)
def --wrapped btop [...args] { _herdr_tui $"\u{f0e4}  btop" "btop" ...$args }

# superfile — nf-md-folder_multiple (U+F024B)
def --wrapped spf       [...args] { _herdr_tui $"\u{f024b}  spf" "spf" ...$args }
def --wrapped superfile [...args] { _herdr_tui $"\u{f024b}  spf" "superfile" ...$args }

# convenience: `dash` → gh-dash (matches old muscle memory)
alias dash = gh-dash
