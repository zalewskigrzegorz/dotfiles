# tuios (agent multiplexer) launcher helpers.

# Short launcher: `os` = `tuios`, flags and subcommands pass through.
# Bare `os` attaches (or creates) a session named after the repo you stand in
# (`dotfiles`, `homelab`), or the machine name from ~ (`Wintermute`), instead
# of tuios's `session-N`.
def --wrapped os [...rest] {
    if ($rest | is-not-empty) { ^tuios ...$rest; return }
    # the common dir, so a worktree still names its main repo
    let git = (^git rev-parse --path-format=absolute --git-common-dir | complete)
    let name = if $git.exit_code == 0 {
        $git.stdout | str trim | path dirname | path basename
    } else if $env.PWD == $env.HOME { sys host | get hostname } else { $env.PWD | path basename }
    # `attach -c` saves no start dir, so an empty workspace opened ~ instead of
    # the repo. `new` fails harmlessly when the session already exists.
    let dir = if $git.exit_code == 0 { ^git rev-parse --show-toplevel | str trim } else { $env.PWD }
    ^tuios new $name --cwd $dir --detach | complete | ignore
    ^tuios attach $name
}

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

# Open the project sessions that are not running yet, coloured and filed by
# projects.tsv. A tape cannot do this: tape commands act inside one session and
# have no NewSession. After os-stop or a reboot the daemon restores saved
# sessions by itself, so this is for a clean start or after closing them.
def os-projects [] {
    let work = ($env.WORK_MONOREPO_DIR | path dirname)
    let projects = [
        $env.WORK_MONOREPO_DIR
        ($work | path join workflows)
        ~/Code/dotfiles
        ~/Code/home-lab
        ~/Code/personal/bazgroly
        ~/Code/personal/HyprMac
    ]
    let open = (^tuios ls --json | from json | get name)
    for dir in ($projects | path expand) {
        let name = ($dir | path basename)
        if $name in $open { continue }
        if not ($dir | path exists) { print -e $"skip ($name): ($dir) missing"; continue }
        ^tuios new $name --cwd $dir --detach
    }
    ^tuios-colorize
    # the lab's first session is session-0; os-mrglaszki attaches to "mrglaszki"
    let lab = (^ssh mrglaszki '/home/linuxbrew/.linuxbrew/bin/tuios ls --json' | from json | get name)
    if "session-0" in $lab and "mrglaszki" not-in $lab {
        ^ssh mrglaszki '/home/linuxbrew/.linuxbrew/bin/tuios rename-session session-0 mrglaszki'
    }
}

# Draw the lab's tuios session here, through the local daemon's ssh link
# ([hosts.mrglaszki] in config.d). Keys are the local ones. Run from a plain
# Ghostty window, not from a tuios pane.
def os-mrglaszki [] {
    if ($env.TUIOS_ENV? | is-not-empty) {
        print -e "You're inside tuios — open a fresh Ghostty window for os-mrglaszki."
        return
    }
    tuios attach --host mrglaszki -c mrglaszki
}
