# SSH auto-sesh
# When logging into a remote machine via SSH and not yet in tmux,
# open the sesh picker. Detaching via `prefix d` returns to the
# nushell prompt; closing the connection leaves the tmux server
# running on the remote.
#
# Local Ghostty is handled separately by ghostty.nu.

# DISABLED. `exec sesh connect` failed on lab — sesh requires a
# session name, so calling it bare prints "Requires at least 1 arg(s)"
# and aborts nu before the prompt is ever drawn. Re-enable once we
# have a robust picker invocation:
#   exec sesh connect (sesh list -i | fzf --no-sort --ansi)
# and decide whether auto-attach on every SSH login is the UX we want.
# if ($env.SSH_CONNECTION? != null) and ($env.TMUX? == null) and ($env.SSH_TTY? != null) {
#     if (which sesh | is-not-empty) {
#         exec sesh connect
#     } else {
#         exec tmux new-session -A -s main
#     }
# }
