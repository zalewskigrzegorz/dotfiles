# Ghostty - Terminal configuration
# Auto-starts tmux when running in Ghostty terminal
# Auto-tmux on Ghostty start: DISABLED by user request — too noisy
# while debugging tmux-resurrect crashes. Manual `tmux` / `ta` works.
# Re-enable by uncommenting once persistence story is stable.
# if ($env.TMUX? == null) and not ($env.SSH_CONNECTION? != null) and ($env.TERM? == "xterm-ghostty") {
#     ^tmux new-session -A -s ghostty
#     exit
# }