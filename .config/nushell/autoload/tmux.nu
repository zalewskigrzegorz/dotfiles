# Tmux - Terminal multiplexer shortcuts
# Override tmux to always use XDG config location

# Create tmux alias that always uses our config file
alias tmux = ^tmux -f $env.TMUX_CONFIG

# Helper function to get tmux sessions
def "tmux sessions" [] {
    let sessions = (^tmux list-sessions -F "#{session_name}" | lines)
    $sessions
}

# Create new tmux session
def tn [name?: string = "main"] { tmux new-session -s $name }

# Attach to tmux session
def --env ta [
    name?: string@"tmux sessions" # Complete with available sessions
] { 
    if ($name | is-empty) { tmux attach } else { tmux attach -t $name }
}

# List tmux sessions
def tl [] { tmux list-sessions }

# Kill tmux session or server
def --env tk [
    name?: string@"tmux sessions" # Complete with available sessions
] { 
    if ($name | is-empty) { tmux kill-server } else { tmux kill-session -t $name }
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