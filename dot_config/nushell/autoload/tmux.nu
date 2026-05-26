# Tmux - Terminal multiplexer shortcuts
# Override tmux to always use XDG config location

# Create tmux alias that always uses our config file
alias tmux = ^tmux -f ($env.TMUX_CONFIG? | default ($env.HOME | path join ".config" "tmux" "tmux.conf"))

# Helper function to get tmux sessions
def "tmux sessions" [] {
    let sessions = (^tmux list-sessions -F "#{session_name}" | lines)
    $sessions
}

# Create new tmux session
def tn [name?: string = "main"] { tmux new-session -s $name }

# Attach to tmux session. With no arg: use `tv tmux` picker if
# television is installed (preview + fuzzy search), else plain
# `tmux attach` (most-recent / errors if none).
def --env ta [
    name?: string@"tmux sessions" # Complete with available sessions
] {
    if ($name | is-not-empty) {
        tmux attach -t $name
        return
    }
    let sessions = (do { ^tmux list-sessions -F "#{session_name}" } | complete)
    if $sessions.exit_code != 0 or ($sessions.stdout | str trim | is-empty) {
        tn
        return
    }
    if (which tv | is-not-empty) {
        let selected = (^tv tmux | str trim)
        if ($selected | is-not-empty) {
            tmux attach -t $selected
        }
    } else {
        tmux attach
    }
}

# List tmux sessions
def tl [] { tmux list-sessions }

# Kill tmux session or server
def --env tk [
    name?: string@"tmux sessions" # Complete with available sessions
] { 
    if ($name | is-empty) { tmux kill-server } else { tmux kill-session -t $name }
}

# Work — set up a 4-window layout in the current tmux session:
#   1: terminal (current shell, renamed)
#   2: git      (lazygit)
#   3: claude   (claude code)
#   4: nvim     (editor)
# Icons mirror zz-tmux-window-wrappers.nu. Idempotent: re-running skips
# windows that already exist by name.
def work [] {
    if ($env.TMUX? == null) {
        print "work: not inside tmux. Run `tn` first."
        return
    }

    let term = $"\u{f120}  terminal"
    let git  = $"\u{e725}  git"
    let cc   = $"\u{f06a9}  claude"
    let edit = $"\u{e62b}  nvim"

    # Window 1: rename caller window to terminal, lock auto-rename off.
    ^tmux set-window-option automatic-rename off
    ^tmux rename-window $term

    let existing = (^tmux list-windows -F "#{window_name}" | lines)

    for spec in [
        { name: $git,  cmd: "lazygit" }
        { name: $cc,   cmd: "claude" }
        { name: $edit, cmd: "nvim" }
    ] {
        if not ($spec.name in $existing) {
            let wid = (^tmux new-window -d -P -F "#{window_id}" -n $spec.name -c $env.PWD $spec.cmd | str trim)
            ^tmux set-window-option -t $wid automatic-rename off
            ^tmux rename-window -t $wid $spec.name
        }
    }

    ^tmux select-window -t:1
}

def basti-nomad [
    target?: string = "nomad-prod" # Autocoplete from tv 
] {
    # derive environment from target (e.g., "nomad-prod" -> "prod"); fallback to target if no dash
    let parts = ($target | split row "-")
    let environment = (if (($parts | length) > 1) { $parts | get 1 } else { $target })

    # ensure dedicated "basti" session exists (detached)
    let basti_exists = ((do { tmux has-session -t "basti" } | complete).exit_code == 0)
    if $basti_exists {
        # session exists; ensure windows are running desired commands
        let windows = (^tmux list-windows -t "basti" -F "#{window_name}" | lines)

        let has_vault = (($windows | where {|w| $w == "vault" } | length) > 0)
        if $has_vault {
            tmux respawn-window -t "basti:vault" -k $"basti connect vault-($environment)"
        } else {
            tmux new-window -t "basti" -n "vault" -d $"basti connect vault-($environment)"
        }

        let has_nomad = (($windows | where {|w| $w == "nomad" } | length) > 0)
        if $has_nomad {
            tmux respawn-window -t "basti:nomad" -k $"basti connect nomad-($environment)"
        } else {
            tmux new-window -t "basti" -n "nomad" -d $"basti connect nomad-($environment)"
        }
    } else {
        # create session with first window (argv form) and add the second window (shell form)
        tmux new-session -d -s "basti" -n "vault" $"basti connect vault-($environment)"
        tmux new-window -t "basti" -n "nomad" -d $"basti connect nomad-($environment)"
    }
}