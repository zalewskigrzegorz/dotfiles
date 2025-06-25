# Ghostty - Terminal configuration
# Auto-starts tmux when running in Ghostty terminal

if ($env.TMUX? == null) and not ($env.SSH_CONNECTION? != null) and ($env.TERM? == "xterm-ghostty") {
    exec tmux new-session -A -s ghostty
} 