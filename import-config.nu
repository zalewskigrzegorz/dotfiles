#!/usr/bin/env nu

# Interactive script to import existing configs into your dotfiles repository

# Sensitive configs that should be added to .gitignore
const SENSITIVE_CONFIGS = ["raycast", "op", "ssh", "keychain", "wallet", "credentials", "1password"]

def main [] {
    print "📦 Import Existing Config to Dotfiles"
    print ""
    
    # Check if we're in a dotfiles directory
    if not ((".git" | path exists) and (".stowrc" | path exists)) {
        print "⚠️ Error: Please run this script from your dotfiles directory"
        return false
    }
    
    # Get configs that are in user ~/.config but not in dotfiles repo (directories only, no symlinks)
    let available_configs = (
        ls ~/.config | where type == 'dir' | get name | path basename | 
        where ($it | str downcase) not-in (ls .config | where type == 'dir' | get name | path basename | str downcase) | sort
    )
    
    if ($available_configs | length) == 0 {
        print "✅ All configs are already managed!"
        return
    }
    
    # Use fzf to select configs
    let fzf_input = ($available_configs | str join "\n")
    let fzf_result = (echo $fzf_input | fzf --multi --prompt='Select configs to import: ' --height=15 --border | complete)
    
    let selected_configs = (
        if $fzf_result.exit_code == 0 {
            $fzf_result.stdout | lines | where $it != ""
        } else {
            []
        }
    )
    
    if ($selected_configs | length) == 0 {
        print "❌ No configs selected. Exiting."
        return
    }
    
    # Show what will be imported using nushell table
    print "📋 Configs to import:"
    let configs_table = ($selected_configs | each {|config|
        let sensitive = if $config in $SENSITIVE_CONFIGS { "🔒 Yes" } else { "No" }
        
        {
            config: $config,
            sensitive: $sensitive
        }
    })
    
    # Display the table
    print ($configs_table | table)
    
    print ""
    let confirm = (input "Continue? (y/N): ")
    if ($confirm | str downcase) != "y" {
        print "❌ Cancelled."
        return
    }
    
    print ""
    
    # Process each selected config
    for $config in $selected_configs {
        let config_path = ($"~/.config/($config)" | path expand)
        if not ($config_path | path exists) {
            print $"⚠️  ($config) doesn't exist, skipping..."
            continue
        }
        
        # Create target directory if it doesn't exist
        mkdir .config
        
        # Copy config
        print $"📋 Copying ($config)..."
        cp -r $config_path $".config/($config)"
        
        # Handle sensitive configs
        if $config in $SENSITIVE_CONFIGS {
            print $"🔒 ($config) added to .gitignore"
            
            # Check if already in gitignore
            let gitignore_content = (open .gitignore | default "")
            if not ($gitignore_content | str contains $"($config)/") {
                $"\n# ($config) - sensitive config\n($config)/\n" | save --append .gitignore
            }
        }
    }
    
    print $"\n✅ Imported ($selected_configs | length) configs"
    print ""
    
    # Ask if user wants to run symlink script
    let run_symlinks = (input "🔗 Run symlink script now? (y/N): ")
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
