export-env {
    let existing = ($env.config.keybindings? | default [])
    $env.config = (
        $env.config
        | default {}
        | upsert keybindings (
            $existing
            | where {|kb| ($kb.name? | default "") != "open_buffer_editor" }
            | append [
                {
                    name: open_buffer_editor
                    modifier: control
                    keycode: char_o
                    mode: [emacs, vi_insert, vi_normal]
                    event: { send: openeditor }
                }
            ]
        )
    )
}
