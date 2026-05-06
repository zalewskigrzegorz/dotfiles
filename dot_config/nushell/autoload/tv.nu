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
# Ctrl+R is added as a fallback only when vendor tv init binding is missing.
export-env {
    let existing_keybindings = ($env.config?.keybindings? | default [])
    let filtered_keybindings = (
        $existing_keybindings
        | where {|kb|
            let name = ($kb.name? | default "")
            ($name != "tv_completion_alt_t") and ($name != "tv_history_fallback")
        }
    )
    let has_tv_ctrl_r = (
        $filtered_keybindings
        | any {|kb|
            let modifier = ($kb.modifier? | default "" | str downcase)
            let keycode = ($kb.keycode? | default "" | str downcase)
            let cmd = ($kb.event?.cmd? | default "")
            (($modifier == "control") and ($keycode == "char_r") and ($cmd == "tv_shell_history"))
        }
    )
    let fallback_history_binding = if $has_tv_ctrl_r { [] } else { [
        {
            name: tv_history_fallback,
            modifier: control,
            keycode: char_r,
            mode: [vi_normal, vi_insert, emacs],
            event: {
                send: executehostcommand,
                cmd: "tv_shell_history"
            }
        }
    ] }

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
            | append $fallback_history_binding
        )
    )
}
