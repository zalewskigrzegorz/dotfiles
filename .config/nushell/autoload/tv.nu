# Television Shell Integration
# Replaces fzf functionality with television (tv) for better performance and features
# Uses fullscreen mode (no --inline) so picker uses full terminal - config.toml ui_scale applies

def tv_smart_autocomplete [] {
    let line = (commandline)
    let cursor = (commandline get-cursor)
    let lhs = ($line | str substring 0..$cursor)
    let rhs = ($line | str substring $cursor..)
    let output = (tv --no-status-bar --autocomplete-prompt $lhs | str trim)

    if ($output | str length) > 0 {
        let needs_space = not ($lhs | str ends-with " ")
        let lhs_with_space = if $needs_space { $"($lhs) " } else { $lhs }
        let new_line = $lhs_with_space + $output + $rhs
        let new_cursor = ($lhs_with_space + $output | str length)
        commandline edit --replace $new_line
        commandline set-cursor $new_cursor
    }
}

# Alt+T for smart autocomplete; Atuin handles history (Ctrl+R)
export-env {
    $env.config = (
        $env.config
        | upsert keybindings (
            $env.config.keybindings
            | append [
                {
                    name: tv_completion,
                    modifier: alt,
                    keycode: char_t,
                    mode: [vi_normal, vi_insert, emacs],
                    event: {
                        send: executehostcommand,
                        cmd: "tv_smart_autocomplete"
                    }
                }
            ]
        )
    )
}