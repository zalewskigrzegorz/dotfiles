# tuios (agent multiplexer) launcher helpers.

# A saved config applies by itself. This pushes the changes that wait for it
# (a new host, wider grants) into the running daemon.
def os-reload [] { tuios config apply }

# Full daemon restart — only needed after a tuios upgrade. Agents come back
# through daemon.resume_agents. Must be run from OUTSIDE tuios: the restart
# ends the pane you're in mid-command. Detach first (prefix+q).
def os-restart [] {
    if ($env.TUIOS_ENV? | is-not-empty) {
        print -e "You're inside tuios — detach first (prefix+q), then run os-restart from a plain terminal."
        return
    }
    tuios restart-server
    tuios
}

# Stop the tuios daemon (detaches everything; sessions are saved and restored on the next start).
def os-stop [] { tuios kill-server }

# Draw the lab's tuios session here, through the local daemon's ssh link
# ([hosts.mrglaszki] in config.d). Keys are the local ones. Run from a plain
# Ghostty window, not from a tuios pane.
def os-mrglaszki [] {
    if ($env.TUIOS_ENV? | is-not-empty) {
        print -e "You're inside tuios — open a fresh Ghostty window for os-mrglaszki."
        return
    }
    tuios attach --host mrglaszki
}
