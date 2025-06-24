#!/usr/bin/env nu

# Apply Symlinks - Backup existing configs and create symlinks via stow
# This script handles all configs in the dotfiles repo at once


def main [] {
    print "🔗 Apply Dotfiles Symlinks"
    print ""
    
    # Check if we're in a dotfiles directory
    if not ((".git" | path exists) and (".stowrc" | path exists)) {
        print "❌ Error: Please run this script from your dotfiles directory"
        return
    }
    
    # Check if .config directory exists in dotfiles
    if not (".config" | path exists) {
        print "❌ Error: No .config directory found in dotfiles"
        return
    }
    
    # Get all configs in dotfiles repo
    let dotfiles_configs = (ls .config | where type == dir | get name | path basename | sort)
    
    if ($dotfiles_configs | length) == 0 {
        print "❌ No configs found in .config directory"
        return
    }
    
    print $"📋 Found ($dotfiles_configs | length) configs in dotfiles:"
    
    # Get symlinked configs (already managed)
    let symlinked_configs = (ls ~/.config | where type == "symlink" | get name | path basename)
    
    # Get configs that need backup (exist as directories in user config but not symlinked)
    let backup_configs = (ls ~/.config | where type == 'dir' | get name | path basename | 
                         where ($it | str downcase) in ($dotfiles_configs | str downcase))
    
    # Get configs that are new (in dotfiles but don't exist in user config)
    let new_configs = ($dotfiles_configs | where ($it | str downcase) not-in (ls ~/.config | get name | path basename | str downcase))
    
    # Create status table
    let configs_status = ($dotfiles_configs | each {|config|
        let status = if $config in $symlinked_configs {
            "🔗"
        } else if $config in $backup_configs {
            "📦" 
        } else {
            "🆕"
        }
        
        {
            config: $config,
            status: $status
        }
    })
    
    # Display status table with summary
    print ($configs_status | table)
    
    # Create summary table
    let summary = ([
        {status: "🔗", count: ($symlinked_configs | length)},
        {status: "🆕", count: ($new_configs | length)},
        {status: "📦", count: ($backup_configs | length)}
    ] | where count > 0)
    
    print ""
    print "📊 Summary:"
    print ($summary | table)
    
    if ($backup_configs | length) == 0 and ($new_configs | length) == 0 {
        print ""
        print "🎉 All configs already properly symlinked!"
        return
    }
    
    print ""
    let confirm = (input "Continue with backup and symlinking? (y/N): ")
    if ($confirm | str downcase) != "y" {
        print "❌ Cancelled."
        return
    }
    
    print ""
    
    # Create backup directory with timestamp
    let timestamp = (date now | format date "%Y%m%d_%H%M%S")
    let backup_dir = $"backups/config_backup_($timestamp)"
    mkdir $backup_dir
    
    print $"📦 Creating backups in ($backup_dir)/"
    
    # Backup configs that need it
    for $config in $backup_configs {
        let source_path = ($"~/.config/($config)" | path expand)
        let backup_path = ($backup_dir | path join $config)
        
        print $"  📋 Backing up ($config)..."
        cp -r $source_path $backup_path
        
        print $"  🗑️  Removing original ($config)..."
        rm -rf $source_path
    }
    
    # Run stow to create all symlinks
    print "🔗 Running stow to create symlinks..."
    let stow_result = (do -i { ^stow . } | complete)
    
    if $stow_result.exit_code != 0 {
        print $"❌ Stow failed: ($stow_result.stderr)"
        print $"💡 Backups are available in ($backup_dir)/ for manual restoration if needed."
        return
    }
    
    print "✅ Stow completed successfully!"
    print ""
    
    # Verify symlinks were created for configs that were new
    print "🔍 Verifying new symlinks..."
    mut verification_failed = false
    
    # Get updated symlink info after stow
    let updated_symlinks = (ls -la ~/.config | where type == "symlink" | select name target)
    
    for $config in $new_configs {
        let symlink_info = ($updated_symlinks | where name == ($"~/.config/($config)" | path expand))
        
        if ($symlink_info | length) > 0 {
            let target = ($symlink_info | get 0.target)
            print $"  ✅ ($config) -> ($target)"
        } else {
            print $"  ❌ ($config) - symlink not created!"
            $verification_failed = true
        }
    }
    
    print ""
    if $verification_failed {
        print "⚠️  Some symlinks failed to create. Check the output above."
        print $"💡 Backups are available in ($backup_dir)/"
    } else {
        print "🎉 All configs successfully symlinked!"
        print $"💡 Backups saved in ($backup_dir)/"
        print "💡 You can delete backups once you've verified everything works"
    }
} 