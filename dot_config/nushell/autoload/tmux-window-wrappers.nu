# Tmux window wrappers
# When running inside tmux, intercept nvim/claude/lazygit and spawn
# a new tmux window with an explicit nerd-font name. Outside tmux,
# pass through to the underlying binary.
#
# automatic-rename is disabled per spawned window so the nerd-font
# plugin does not overwrite our pinned name.

def --wrapped nvim [...args] {
    if ($env.TMUX? != null) {
        let name = "  nvim"
        ^tmux new-window -n $name -c $env.PWD nvim ...$args
        ^tmux set-window-option automatic-rename off
    } else {
        ^nvim ...$args
    }
}

def --wrapped claude [...args] {
    if ($env.TMUX? != null) {
        let name = "󰚩  claude"
        ^tmux new-window -n $name -c $env.PWD claude ...$args
        ^tmux set-window-option automatic-rename off
    } else {
        ^claude ...$args
    }
}

def lazygit [] {
    if ($env.TMUX? != null) {
        let name = "  git"
        ^tmux new-window -n $name -c $env.PWD lazygit
        ^tmux set-window-option automatic-rename off
    } else {
        ^lazygit
    }
}
