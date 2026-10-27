# tuios TUI tab wrappers.
# When inside tuios, intercept common TUI commands: rename the CURRENT tab (a
# tuios workspace) to a nerd-font icon + name for the duration of the TUI, then
# restore the tab's previous name on exit (works on ctrl-c / error too).
# Outside tuios, pass through to the underlying binary unchanged.
#
# File name prefix `zz-` ensures this autoload runs AFTER `vim.nu` so these defs
# shadow the `alias vim = nvim` / `alias vi = nvim` declared there. `lg` (alias →
# lazygit) and `dash` (alias → gh-dash) flow through these wrappers too.
#
# Use \u{xxxx} escapes for icons so codepoints survive edits (literal glyphs in
# source have been silently stripped before).

# Shared helper. Renames the workspace that holds the caller's pane to `name`,
# runs `cmd ...args` in the current pane, then restores the old name (an
# unnamed workspace gets its name cleared). Outside tuios (TUIOS_PANE_ID unset)
# just runs the command.
def --wrapped _tuios_tui [
    name: string
    ...cmd_and_args  # first element is the executable, rest are args
] {
    let cmd = ($cmd_and_args | first)
    let rest = ($cmd_and_args | skip 1)
    let pane = ($env.TUIOS_PANE_ID? | default "")

    if ($pane | is-empty) {
        run-external $cmd ...$rest
        return
    }

    # the pane's workspace number and its current name, to put back afterwards
    let row = (
        try {
            (do { ^tuios list-windows --all --json } | complete).stdout
            | from json | get -o windows | default []
            | where window_id == $pane | get -o 0
        } catch { null }
    )
    if $row == null {
        run-external $cmd ...$rest
        return
    }
    let ws = ($row.workspace | into string)
    let prev = ($row | get -o workspace_name | default "")

    do { ^tuios set-workspace-name $ws $name } | complete | ignore
    try { run-external $cmd ...$rest }
    let restore = if ($prev | is-empty) { [] } else { [$prev] }
    do { ^tuios set-workspace-name $ws ...$restore } | complete | ignore
}

# Editors — nf-custom-vim (U+E62B)
def --wrapped nvim [...args] { _tuios_tui $"\u{e62b}  nvim" "nvim" ...$args }
def --wrapped vim  [...args] { _tuios_tui $"\u{e62b}  nvim" "nvim" ...$args }
def --wrapped vi   [...args] { _tuios_tui $"\u{e62b}  nvim" "nvim" ...$args }

# lazygit — nf-dev-git (U+E725). `lg` alias expands to lazygit → hits this def.
def --wrapped lazygit [...args] { _tuios_tui $"\u{e725}  git" "lazygit" ...$args }

# GitHub dashboard (gh dash extension) — nf-md-github (U+F0865)
def --wrapped gh-dash [...args] { _tuios_tui $"\u{f0865}  gh-dash" "gh" "dash" ...$args }

# lazydocker — nf-md-docker (U+F0868)
def --wrapped lazydocker [...args] { _tuios_tui $"\u{f0868}  docker" "lazydocker" ...$args }

# btop — nf-md-chart_areaspline (U+F0E4)
def --wrapped btop [...args] { _tuios_tui $"\u{f0e4}  btop" "btop" ...$args }

# superfile — nf-md-folder_multiple (U+F024B)
def --wrapped spf       [...args] { _tuios_tui $"\u{f024b}  spf" "spf" ...$args }
def --wrapped superfile [...args] { _tuios_tui $"\u{f024b}  spf" "superfile" ...$args }

# convenience: `dash` → gh-dash (matches old muscle memory)
alias dash = gh-dash
