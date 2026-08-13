# Accept the history hint one word at a time.
# Default is alt+f / alt+right, which macOS eats (Option types ñ, ł, ...)
# because ghostty runs with `macos-option-as-alt = false`.
export-env {
    let existing = ($env.config?.keybindings? | default [])
    $env.config = (
        $env.config
        | default {}
        | upsert keybindings (
            $existing
            | where {|kb| ($kb.name? | default "") != "history_hint_word" }
            | append [
                {
                    name: history_hint_word
                    modifier: shift
                    keycode: right
                    mode: [emacs, vi_insert, vi_normal]
                    event: { send: historyhintwordcomplete }
                }
            ]
        )
    )
}
