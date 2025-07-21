# Television Shell Integration
# Replaces fzf functionality with television (tv) for better performance and features

# Initialize television for nushell using the built-in integration
try {
    tv --version | ignore
    
    mkdir ($nu.data-dir | path join "vendor/autoload")
    
    tv init nu | save -f ($nu.data-dir | path join "vendor/autoload/tv.nu")
    
} catch {
    print "Warning: Television (tv) not found. Install with: cargo install television"
}

# Override the default keybindings to use Alt+T for smart autocomplete only
# Atuin handles history, so we don't need Ctrl+R for television
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