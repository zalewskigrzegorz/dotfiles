# Tmux window wrappers
# When running inside tmux, intercept nvim/claude/lazygit (plus vim/vi
# aliases defined in vim.nu) and spawn a new tmux window with an explicit
# nerd-font name. Outside tmux, pass through to the underlying binary.
#
# File name prefix `zz-` ensures this autoload runs AFTER `vim.nu`, so our
# defs shadow the `alias vim = nvim` / `alias vi = nvim` declared there.
#
# Window targeting: `tmux new-window -d -P -F "#{window_id}"` returns the
# new window's ID. We then set automatic-rename off and rename explicitly,
# targeting that ID — otherwise `set-window-option` would apply to the
# caller pane's current window (the one we just left), not the new one.

def --wrapped nvim [...args] {
    if ($env.TMUX? != null) {
        let name = "  nvim"
        let wid = (^tmux new-window -d -P -F "#{window_id}" -n $name -c $env.PWD nvim ...$args | str trim)
        ^tmux set-window-option -t $wid automatic-rename off
        ^tmux rename-window -t $wid $name
        ^tmux select-window -t $wid
    } else {
        ^nvim ...$args
    }
}

# Shadow the aliases from vim.nu so they also spawn windows.
def --wrapped vim [...args] { nvim ...$args }
def --wrapped vi  [...args] { nvim ...$args }

def --wrapped claude [...args] {
    if ($env.TMUX? != null) {
        let name = "󰚩  claude"
        let wid = (^tmux new-window -d -P -F "#{window_id}" -n $name -c $env.PWD claude ...$args | str trim)
        ^tmux set-window-option -t $wid automatic-rename off
        ^tmux rename-window -t $wid $name
        ^tmux select-window -t $wid
    } else {
        ^claude ...$args
    }
}

def lazygit [] {
    if ($env.TMUX? != null) {
        let name = "  git"
        let wid = (^tmux new-window -d -P -F "#{window_id}" -n $name -c $env.PWD lazygit | str trim)
        ^tmux set-window-option -t $wid automatic-rename off
        ^tmux rename-window -t $wid $name
        ^tmux select-window -t $wid
    } else {
        ^lazygit
    }
}
