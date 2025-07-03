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