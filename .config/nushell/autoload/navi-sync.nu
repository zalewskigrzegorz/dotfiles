# Navi-Obsidian Synchronization Helper
# Synchronizes navi cheat files with Obsidian markdown files
# Available globally from any location

# Get the script path
def get-script-path [] {
    # Try to find dotfiles directory relative to config
    let config_dir = ($nu.config-path | path dirname)
    let script_path = ($config_dir | path join ".." ".." ".." "sync-navi-obsidian.nu" | path expand)
    
    if ($script_path | path exists) {
        $script_path
    } else {
        # Fallback: try common locations
        let home = $env.HOME
        let fallback_path = ($home | path join "Code" "dotfiles" "sync-navi-obsidian.nu")
        if ($fallback_path | path exists) {
            $fallback_path
        } else {
            error make {
                msg: "sync-navi-obsidian.nu not found"
                label: {
                    text: "Please ensure the dotfiles repository is accessible"
                }
            }
        }
    }
}

# Sync Navi cheats with Obsidian
# Usage: navi-sync [--mode: all|to-obsidian|from-obsidian]
export def "navi-sync" [
    --mode: string = "all"  # Sync mode: "all" (bidirectional), "to-obsidian", or "from-obsidian"
] {
    let script_path = (get-script-path)
    
    # Run the script as a subprocess
    nu $script_path --mode $mode
}
