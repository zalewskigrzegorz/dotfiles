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
    
    # Require at least .config or another stow package (e.g. .claude)
    let has_config = (".config" | path exists)
    let has_claude = (".claude" | path exists)
    if not $has_config and not $has_claude {
        print "❌ Error: No .config or .claude directory found in dotfiles"
        return
    }
    
    # Get all configs in dotfiles repo (from .config)
    let dotfiles_configs = (if $has_config {
        ls .config | where type == dir | get name | path basename | sort
    } else {
        []
    })
    
    if ($dotfiles_configs | length) == 0 and not $has_claude {
        print "❌ No configs found in .config directory"
        return
    }
    
    print $"📋 Found ($dotfiles_configs | length) configs in dotfiles:"
    
    let home_config_exists = (("~/.config" | path expand) | path exists)
    # Get symlinked configs (already managed)
    let symlinked_configs = (if $home_config_exists { ls ~/.config | where type == "symlink" | get name | path basename } else { [] })
    
    # Get configs that need backup (exist as directories in user config but not symlinked)
    let backup_configs = (if $home_config_exists {
        ls ~/.config | where type == 'dir' | get name | path basename |
        where ($it | str downcase) in ($dotfiles_configs | str downcase)
    } else { [] })
    
    # Get configs that are new (in dotfiles but don't exist in user config)
    let new_configs = (if $home_config_exists {
        $dotfiles_configs | where ($it | str downcase) not-in (ls ~/.config | get name | path basename | str downcase)
    } else { $dotfiles_configs })
    
    # ~/.claude: stow tylko gdy w repo jest pełne .claude (hooks/peon-ping), żeby nie zepsuć peon-ping
    let claude_home = ("~/.claude" | path expand)
    let claude_complete = ($has_claude and (".claude/hooks/peon-ping" | path exists))
    let claude_entry = (ls ("~" | path expand) | where name == $claude_home | get 0?)
    let claude_needs_backup = ($claude_complete and ($claude_home | path exists) and (($claude_entry | default { type: "" }).type != "symlink"))
    
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
    if $has_claude {
        let claude_status = if not $claude_complete {
            "⚠️ skip (brak hooks/peon-ping w repo)"
        } else if $claude_needs_backup {
            "📦"
        } else if (($claude_home | path exists) == false) {
            "🆕"
        } else {
            "🔗"
        }
        print ([{ config: ".claude (extra)", status: $claude_status }] | table)
    }
    
    # Create summary table
    let summary = ([
        {status: "🔗", count: ($symlinked_configs | length)},
        {status: "🆕", count: ($new_configs | length)},
        {status: "📦", count: ($backup_configs | length)}
    ] | where count > 0)
    
    print ""
    print "📊 Summary:"
    print ($summary | table)
    
    let something_to_do = ($backup_configs | length) > 0 or ($new_configs | length) > 0 or $claude_needs_backup
    if not $something_to_do {
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
    
    # Backup ~/.claude if needed (cały katalog, żeby stow mógł dać symlink)
    if $claude_needs_backup {
        let claude_backup_path = ($backup_dir | path join ".claude")
        print "  📋 Backing up .claude..."
        cp -r $claude_home $claude_backup_path
        print "  🗑️  Removing original ~/.claude..."
        rm -rf $claude_home
    }
    
    # Run stow (pomiń .claude jeśli niekompletne – tymczasowo ukryj, żeby nie zepsuć ~/.claude)
    mut need_restore_claude = false
    if $has_claude and (not $claude_complete) {
        print "⚠️  Pomijam .claude (brak hooks/peon-ping w repo) – nie nadpisuję ~/.claude"
        ^mv .claude .claude.no-stow
        $need_restore_claude = true
    }
    print "🔗 Running stow to create symlinks..."
    let stow_result = (do -i { ^stow . } | complete)
    if $need_restore_claude {
        ^mv .claude.no-stow .claude
    }
    
    if $stow_result.exit_code != 0 {
        print $"❌ Stow failed: ($stow_result.stderr)"
        if $need_restore_claude {
            ^mv .claude.no-stow .claude
        }
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

    # Sync Cursor agent-skills (copy, no symlinks) if source exists
    if ("agent-skills" | path exists) {
        print ""
        print "📂 Syncing Cursor agent-skills to ~/.cursor/skills..."
        let sync_result = (do -i { ^./bin/sync-cursor-skills } | complete)
        if $sync_result.exit_code == 0 {
            print $sync_result.stdout
        } else {
            print $"⚠️  Skill sync warning: ($sync_result.stderr)"
        }
    }
} 