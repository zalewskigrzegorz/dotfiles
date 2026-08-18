# herdr (agent multiplexer) launcher helpers.

# Start or attach the herdr TUI.
def --env hd [] { herdr }

# Reload config into the running server (no restart). Same as prefix+shift+r.
# Use this for config.toml changes. For autoload (nu) changes, just open a new tab.
def hd-reload [] { herdr server reload-config }

# Full server restart — only needed after a herdr binary upgrade.
# Must be run from OUTSIDE herdr: stopping the server from inside kills the pane
# you're in mid-command ("unexpected end of stream"). Detach first (prefix+q).
def hd-restart [] {
    if ($env.HERDR_ENV? | is-not-empty) {
        print -e "You're inside herdr — detach first (prefix+q), then run hd-restart from a plain terminal."
        return
    }
    herdr server stop
    herdr
}

# Stop the herdr server (detaches everything, processes end).
def hd-stop [] { herdr server stop }

# Attach the lab's herdr server as a thin client (client-server, not ssh+remote shell).
# --remote-keybindings server: the LAB interprets the prefix with its own config
# (ctrl+space). Default `local` does NOT intercept the prefix in remote-attach,
# so the leader appears dead. Run from a plain Ghostty window (not nested in herdr).
def hd-lab [] {
    if ($env.HERDR_ENV? | is-not-empty) {
        print -e "You're inside herdr — --remote only works from a plain terminal. Open a fresh Ghostty window."
        return
    }
    herdr --remote lab --remote-keybindings server
}
