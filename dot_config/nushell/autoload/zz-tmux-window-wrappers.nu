# Tmux window wrappers
# When inside tmux, intercept common TUI commands and spawn a new tmux
# window with an explicit nerd-font name + icon. Outside tmux, pass
# through to the underlying binary.
#
# File name prefix `zz-` ensures this autoload runs AFTER `vim.nu`, so
# our defs shadow the `alias vim = nvim` / `alias vi = nvim` declared
# there.
#
# Window targeting: `tmux new-window -d -P -F "#{window_id}"` returns
# the new window's ID. We then set automatic-rename off and rename
# explicitly, targeting that ID — otherwise `set-window-option` would
# apply to the caller pane's current window (the one we just left),
# not the new one.

# Shared helper. Spawns `cmd ...args` in a new tmux window labelled
# `name`, with auto-rename disabled so the icon stays put. Outside
# tmux, runs the command directly in the current shell.
def --wrapped _tui_window [
    name: string  # e.g. "  nvim"
    cmd: string   # e.g. "nvim"
    ...args
] {
    if ($env.TMUX? != null) {
        let wid = (^tmux new-window -d -P -F "#{window_id}" -n $name -c $env.PWD $cmd ...$args | str trim)
        ^tmux set-window-option -t $wid automatic-rename off
        ^tmux rename-window -t $wid $name
        ^tmux select-window -t $wid
    } else {
        run-external $cmd ...$args
    }
}

# Editors
def --wrapped nvim   [...args] { _tui_window "  nvim"      "nvim"       ...$args }
def --wrapped vim    [...args] { _tui_window "  nvim"      "nvim"       ...$args }
def --wrapped vi     [...args] { _tui_window "  nvim"      "nvim"       ...$args }

# AI / agents
def --wrapped claude [...args] { _tui_window "󰚩  claude"   "claude"     ...$args }

# Git / repo TUIs
def --wrapped lazygit [...args] { _tui_window "  git"      "lazygit"    ...$args }

# Containers
def --wrapped lazydocker [...args] { _tui_window "  docker" "lazydocker" ...$args }

# System monitors
def --wrapped btop   [...args] { _tui_window "  btop"      "btop"       ...$args }
def --wrapped htop   [...args] { _tui_window "  htop"      "htop"       ...$args }

# Kubernetes (if/when installed)
def --wrapped k9s    [...args] { _tui_window "󱃾  k9s"      "k9s"        ...$args }
