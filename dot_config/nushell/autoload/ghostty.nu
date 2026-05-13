# Ghostty - Terminal configuration
# Auto-starts tmux when running in Ghostty terminal
if ($env.TMUX? == null) and not ($env.SSH_CONNECTION? != null) and ($env.TERM? == "xterm-ghostty") {
    # NOTE: avoid `exec` here — nu's exec during autoload races with TTY
    # setup in Ghostty and tmux exits immediately, closing the window.
    # Plain call + exit gives the same UX (closing tmux closes the term).
    ^tmux new-session -A -s ghostty
    exit
}