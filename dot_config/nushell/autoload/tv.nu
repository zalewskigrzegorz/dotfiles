# Television Shell Integration
# Replaces fzf functionality with television (tv) for better performance and features
# Uses fullscreen mode (no --inline) so picker uses full terminal - config.toml ui_scale applies

def tv_smart_autocomplete [] {
    let line = (commandline)
    let cursor = (commandline get-cursor)
    let lhs = ($line | str substring 0..$cursor)
    let rhs = ($line | str substring $cursor..)
    let output = (^tv --no-status-bar --autocomplete-prompt $lhs | str trim)

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
    let output = (^tv nu-history --inline --input $lhs | str trim)

    if ($output | is-not-empty) {
        commandline edit --replace $output
        commandline set-cursor --end
    }
}

# Pastes the selected tool into the prompt buffer (no execution). User hits Enter themselves.
def tv_tools_pick [] {
    let output = (^tv tools | str trim)
    if ($output | is-not-empty) {
        commandline edit --replace $output
        commandline set-cursor --end
    }
}

# Completer: list of available TV channels (from `tv list-channels`).
def "nu-complete tv-channels" []: nothing -> list<string> {
    ^tv list-channels | lines | each { |l| $l | str trim } | where ($it | is-not-empty)
}

# Wrap `tv` so that running it with no channel defaults to the `tools` channel
# AND immediately executes the picked tool. Channel arg gets tab-completion.
def --wrapped tv [
    channel?: string@"nu-complete tv-channels"  # TV channel (tab-completes)
    ...args: string
] {
    if ($channel | is-empty) {
        let pick = (^tv tools | str trim)
        if ($pick | is-not-empty) {
            let parts = ($pick | split row -r '\s+')
            run-external ($parts | first) ...($parts | skip 1)
        }
    } else {
        ^tv $channel ...$args
    }
}

# Ctrl+T — smart autocomplete (tv_smart_autocomplete), context-aware.
# Alt+T removed: Ghostty has macos-option-as-alt=false so Option+T = † literal.
# Ctrl+R is owned by fzf-history.nu.
# Tool picker (tv_tools_pick) is unbound — reach it via bare `tv` (wrapper runs it).
export-env {
    let existing_keybindings = ($env.config?.keybindings? | default [])
    let filtered_keybindings = (
        $existing_keybindings
        | where {|kb|
            let name = ($kb.name? | default "")
            ($name != "tv_completion_alt_t") and ($name != "tv_history_fallback") and ($name != "tv_tools_ctrl_t") and ($name != "tv_smart_ctrl_t")
        }
    )

    $env.config = (
        $env.config
        | upsert keybindings (
            $filtered_keybindings
            | append [
                {
                    name: tv_smart_ctrl_t,
                    modifier: control,
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
