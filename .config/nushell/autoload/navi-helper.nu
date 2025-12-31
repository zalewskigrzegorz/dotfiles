# Navi Cheatsheet Helper
# Quick way to add new commands to your Navi cheatsheets

# Add a new command to a Navi cheatsheet
# Usage: navi-add "description" "command" [cheatsheet_file]
# Example: navi-add "List all tmux sessions" "tmux ls" tmux
export def "navi-add" [
    description: string,  # Description of what the command does
    command: string,      # The actual command
    cheatsheet?: string@"nu-complete navi-cheatsheets" = "development"  # Which cheatsheet file to add to (default: development.cheat)
] {
    let navi_cheats_dir = ($env.HOME | path join ".config" "navi" "cheats")
    let cheat_file = ($navi_cheats_dir | path join $"($cheatsheet).cheat")
    
    # Ensure directory exists
    if not ($navi_cheats_dir | path exists) {
        mkdir $navi_cheats_dir
    }
    
    # Check if file exists, if not create it with basic tags
    if not ($cheat_file | path exists) {
        let tags = if $cheatsheet == "development" {
            "development, git, pnpm, coding, shortcuts, nushell"
        } else {
            $cheatsheet
        }
        $"% ($tags)" | save -f $cheat_file
        print $"Created new cheatsheet file: ($cheat_file)"
    }
    
    # Append the new command
    let entry = $"\n# ($description)\n($command)\n"
    $entry | save --append $cheat_file
    
    print $"✅ Added to ($cheat_file):"
    print $"   Description: ($description)"
    print $"   Command: ($command)"
    print $""
    print $"💡 Tip: Press <prefix> + B in tmux to search for this command!"
}

# Completion function for navi cheatsheet names
# Used by navi-edit and navi-add for autocomplete
def "nu-complete navi-cheatsheets" [] {
    let cheatsheets = (navi-list)
    if ($cheatsheets | is-empty) {
        return []
    }
    $cheatsheets | get name
}

# List all your custom cheatsheets
# Returns a structured table that can be queried, filtered, and sorted
export def "navi-list" [] {
    let navi_cheats_dir = ($env.HOME | path join ".config" "navi" "cheats")
    
    if not ($navi_cheats_dir | path exists) {
        return []
    }
    
    ls $navi_cheats_dir 
    | where type == file 
    | where ($it.name | str ends-with ".cheat")
    | each { |file|
        let file_path = if ($file.name | path type) == "absolute" {
            $file.name
        } else {
            ($navi_cheats_dir | path join $file.name)
        }
        let filename = ($file_path | path basename)
        let name = ($filename | str replace ".cheat" "")
        let count = (open $file_path | lines | where ($it | str starts-with "#") | length)
        {
            name: $name
            file: $filename
            path: ($file_path | into string)
            commands: $count
            size: $file.size
            modified: $file.modified
        }
    }
}

# Open a cheatsheet file for editing
export def "navi-edit" [
    cheatsheet: string@"nu-complete navi-cheatsheets" = "development"  # Which cheatsheet to edit
] {
    let navi_cheats_dir = ($env.HOME | path join ".config" "navi" "cheats")
    let cheat_file = ($navi_cheats_dir | path join $"($cheatsheet).cheat")
    
    if not ($cheat_file | path exists) {
        print $"❌ Cheatsheet '($cheatsheet)' not found!"
        print $"Available cheatsheets:"
        navi-list
        return
    }
    
    nvim $cheat_file
}

# Search for a command in your cheatsheets
# Returns a structured table with matches that can be queried and filtered
export def "navi-search" [
    query: string  # Search term
] {
    let navi_cheats_dir = ($env.HOME | path join ".config" "navi" "cheats")
    
    if not ($navi_cheats_dir | path exists) {
        return []
    }
    
    ls $navi_cheats_dir 
    | where type == file 
    | where ($it.name | str ends-with ".cheat")
    | each { |file|
        let file_path = if ($file.name | path type) == "absolute" {
            $file.name
        } else {
            ($navi_cheats_dir | path join $file.name)
        }
        let filename = ($file_path | path basename)
        let name = ($filename | str replace ".cheat" "")
        let content = (open $file_path)
        let matches = ($content | lines | enumerate | where { |line|
            ($line.item | str contains -i $query)
        })
        
        if ($matches | length) > 0 {
            $matches | each { |match|
                {
                    cheatsheet: $name
                    file: $filename
                    path: ($file_path | into string)
                    line_number: ($match.index + 1)
                    content: ($match.item | into string)
                }
            }
        } else {
            []
        }
    }
    | flatten
}
