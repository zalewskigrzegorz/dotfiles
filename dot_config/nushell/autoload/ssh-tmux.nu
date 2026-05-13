# SSH auto-sesh
# When logging into a remote machine via SSH and not yet in tmux,
# open the sesh picker. Detaching via `prefix d` returns to the
# nushell prompt; closing the connection leaves the tmux server
# running on the remote.
#
# Local Ghostty is handled separately by ghostty.nu.

if ($env.SSH_CONNECTION? != null) and ($env.TMUX? == null) and ($env.SSH_TTY? != null) {
    if (which sesh | is-not-empty) {
        exec sesh connect
    } else {
        # Fallback: attach or create a single 'main' session
        exec tmux new-session -A -s main
    }
}
