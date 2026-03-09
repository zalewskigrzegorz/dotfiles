#!/usr/bin/env nu

# Interactive script to import existing configs into your dotfiles repository

# Sensitive configs that should be added to .gitignore
const SENSITIVE_CONFIGS = ["raycast", "op", "ssh", "keychain", "wallet", "credentials", "1password"]

# Lokalizacje poza ~/.config do importu (ścieżka w home, katalog w repo)
const EXTRA_IMPORT_LOCATIONS = [
    { home: "~/.claude", repo_dir: ".claude", name: "Claude (.claude)" }
]

def main [] {
    print "📦 Import Existing Config to Dotfiles"
    print ""
    
    # Check if we're in a dotfiles directory
    if not ((".git" | path exists) and (".stowrc" | path exists)) {
        print "⚠️ Error: Please run this script from your dotfiles directory"
        return false
    }
    
    # --- Import z ~/.config (jak dotąd) ---
    # Get configs that are in user ~/.config but not in dotfiles repo (directories only, no symlinks)
    let available_configs = (
        ls ~/.config | where type == 'dir' | get name | path basename | 
        where ($it | str downcase) not-in (ls .config | where type == 'dir' | get name | path basename | str downcase) | sort
    )
    
    # --- Import z innych lokalizacji (np. ~/.claude) ---
    let extra_to_offer = ($EXTRA_IMPORT_LOCATIONS | where { |it|
        let home_exists = (($it.home | path expand) | path exists)
        let repo_missing = (($it.repo_dir | path exists) == false)
        $home_exists and $repo_missing
    })
    
    if ($available_configs | length) == 0 and ($extra_to_offer | length) == 0 {
        print "✅ All configs are already managed (including .config and extra locations)!"
        return
    }
    
    mut anything_imported = false
    
    if ($available_configs | length) > 0 {
        # Use fzf to select configs (z ~/.config)
        let fzf_input = ($available_configs | str join "\n")
        let fzf_result = (echo $fzf_input | fzf --multi --prompt='Select configs to import (from ~/.config): ' --height=15 --border | complete)
        
        let selected_configs = (
            if $fzf_result.exit_code == 0 {
                $fzf_result.stdout | lines | where $it != ""
            } else {
                []
            }
        )
        
        if ($selected_configs | length) > 0 {
            # Show what will be imported using nushell table
            print "📋 Configs to import (from ~/.config):"
            let configs_table = ($selected_configs | each {|config|
                let sensitive = if $config in $SENSITIVE_CONFIGS { "🔒 Yes" } else { "No" }
                { config: $config, sensitive: $sensitive }
            })
            print ($configs_table | table)
            print ""
            let confirm = (input 'Continue? (y/N): ')
            if ($confirm | str downcase) == "y" {
                for $config in $selected_configs {
                    let config_path = ($"~/.config/($config)" | path expand)
                    if not ($config_path | path exists) {
                        print $"⚠️  ($config) doesn't exist, skipping..."
                        continue
                    }
                    mkdir .config
                    print $"📋 Copying ($config)..."
                    cp -r $config_path $".config/($config)"
                    if $config in $SENSITIVE_CONFIGS {
                        print $"🔒 ($config) added to .gitignore"
                        let gitignore_content = (open .gitignore | default "")
                        if not ($gitignore_content | str contains $"($config)/") {
                            $"\n# ($config) - sensitive config\n($config)/\n" | save --append .gitignore
                        }
                    }
                }
                $anything_imported = true
                print $"\n✅ Imported ($selected_configs | length) configs from ~/.config"
            }
        }
        print ""
    }
    
    # --- Import z innych lokalizacji (np. ~/.claude) ---
    if ($extra_to_offer | length) > 0 {
        print "📂 Other locations (not under ~/.config):"
        print ($extra_to_offer | each {|loc| $"  - ($loc.name): ($loc.home)" } | str join "\n")
        let confirm_extra = (input ($"\n" + 'Import these into dotfiles? (y/N): '))
        if ($confirm_extra | str downcase) == "y" {
            for $loc in $extra_to_offer {
                let src = ($loc.home | path expand)
                let dest = $loc.repo_dir
                if ($src | path exists) and (($dest | path exists) == false) {
                    print $"📋 Copying ($loc.name) to ($dest)..."
                    cp -r $src $dest
                    $anything_imported = true
                }
            }
            print "✅ Extra locations imported."
        }
        print ""
    }
    
    if not $anything_imported {
        print "❌ Nothing imported."
        return
    }
    
    print ""
    
    # Ask if user wants to run symlink script
    let run_symlinks = (input '🔗 Run symlink script now? (y/N): ')
    if ($run_symlinks | str downcase) == "y" {
        print ""
        print "🚀 Running apply-symlinks.nu..."
        nu apply-symlinks.nu
    } else {
        print ""
        print "🚀 Next steps:"
        print "1. Run: nu apply-symlinks.nu"
        print "2. Test & commit"
    }
}
