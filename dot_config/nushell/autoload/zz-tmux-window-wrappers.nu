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
    name: string
    ...cmd_and_args  # first element is the executable, rest are args
] {
    let cmd = ($cmd_and_args | first)
    let rest = ($cmd_and_args | skip 1)
    if ($env.TMUX? != null) {
        let wid = (^tmux new-window -d -P -F "#{window_id}" -n $name -c $env.PWD $cmd ...$rest | str trim)
        ^tmux set-window-option -t $wid automatic-rename off
        ^tmux rename-window -t $wid $name
        ^tmux select-window -t $wid
    } else {
        run-external $cmd ...$rest
    }
}

# Editors — nf-custom-vim (U+E62B)
def --wrapped nvim   [...args] { _tui_window $"\u{e62b}  nvim"      "nvim"   ...$args }
def --wrapped vim    [...args] { _tui_window $"\u{e62b}  nvim"      "nvim"   ...$args }
def --wrapped vi     [...args] { _tui_window $"\u{e62b}  nvim"      "nvim"   ...$args }

# AI / agents — nf-md-robot (U+F06A9)
def --wrapped claude [...args] { _tui_window $"\u{f06a9}  claude"   "claude" ...$args }

# Git TUIs — nf-dev-git_branch (U+E725)
def --wrapped lazygit [...args] { _tui_window $"\u{e725}  git"      "lazygit" ...$args }

# GitHub dashboard (gh dash extension) — nf-md-github (U+F0865)
def --wrapped gh-dash [...args] { _tui_window $"\u{f0865}  gh-dash" "gh" "dash" ...$args }

# Containers — nf-md-docker (U+F0868)
def --wrapped lazydocker [...args] { _tui_window $"\u{f0868}  docker" "lazydocker" ...$args }

# System monitor — nf-fa-tachometer (U+F0E4)
def --wrapped btop   [...args] { _tui_window $"\u{f0e4}  btop"      "btop"   ...$args }

# File manager (superfile) — nf-md-folder (U+F024B). Both `spf` and `superfile` bind.
def --wrapped spf       [...args] { _tui_window $"\u{f024b}  spf"   "spf"       ...$args }
def --wrapped superfile [...args] { _tui_window $"\u{f024b}  spf"   "superfile" ...$args }

# Spotify TUI — nf-fa-spotify (U+F1BC). Without the wrapper, tmux auto-rename
# picks up the prompt buffer text as the window title instead of "spotify".
# KITTY_WINDOW_ID is forced so viuer (the image-rendering lib spotify_player
# uses) treats this pane as kitty-graphics-capable. Without it, TERM_PROGRAM
# inside tmux is "tmux", viuer can't detect Ghostty's identity, and the
# album cover falls back to block-art instead of proper image escape codes.
def --wrapped spotify_player [...args] {
    if ($env.TMUX? != null) {
        let name = $"\u{f1bc}  spotify"
        let wid = (^tmux new-window -d -P -F "#{window_id}" -n $name -e "KITTY_WINDOW_ID=1" -c $env.PWD "spotify_player" ...$args | str trim)
        ^tmux set-window-option -t $wid automatic-rename off
        ^tmux rename-window -t $wid $name
        ^tmux select-window -t $wid
    } else {
        with-env { KITTY_WINDOW_ID: "1" } {
            run-external "spotify_player" ...$args
        }
    }
}
