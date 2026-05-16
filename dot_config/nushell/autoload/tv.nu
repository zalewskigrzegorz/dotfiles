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

def tv_shell_history [] {
    let line = (commandline)
    let cursor = (commandline get-cursor)
    let lhs = ($line | str substring 0..$cursor)
    let output = (tv nu-history --inline --input $lhs | str trim)

    if ($output | is-not-empty) {
        commandline edit --replace $output
        commandline set-cursor --end
    }
}

# Alt+T for smart autocomplete.
# Ctrl+R is owned by fzf-history.nu (Television's filter quality wasn't good enough).
# To re-enable TV history search, drop a {modifier: control, keycode: char_r,
# cmd: "tv_shell_history"} entry into $env.config.keybindings manually.
export-env {
    let existing_keybindings = ($env.config?.keybindings? | default [])
    let filtered_keybindings = (
        $existing_keybindings
        | where {|kb|
            let name = ($kb.name? | default "")
            ($name != "tv_completion_alt_t") and ($name != "tv_history_fallback")
        }
    )

    $env.config = (
        $env.config
        | upsert keybindings (
            $filtered_keybindings
            | append [
                {
                    name: tv_completion_alt_t,
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
