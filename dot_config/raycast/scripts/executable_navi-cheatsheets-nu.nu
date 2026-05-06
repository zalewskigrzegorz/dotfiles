#!/usr/bin/env nu

# @raycast.schemaVersion 1
# @raycast.title Search Navi Cheatsheets (Nushell)
# @raycast.mode fullOutput
# @raycast.icon 📚
# @raycast.packageName Navi Cheatsheets

# Documentation:
# @raycast.description Search through your Navi cheatsheet library using Nushell
# @raycast.author Grzegorz Zalewski
# @raycast.authorURL https://raycast.com/zalewskigrzegorz

# @raycast.argument1 { "type": "text", "placeholder": "Search query", "optional": true }

# Default cheatsheets path
let cheats_path = ($env.HOME | path join ".config" "navi" "cheats")

# Get search query from Raycast (passed as first argument)
let query = ($env.RAYCAST_ARGV? | default "" | split row " " | get 0? | default "")

# Function to parse a cheat file
def parse-cheat-file [file: string] {
    let cheatsheet_name = ($file | path basename | str replace ".cheat" "")
    let content = (open $file | lines | enumerate)
    mut current_description = ""
    mut results = []

    for line in $content {
        let line_text = $line.item
        let line_num = ($line.index + 1)

        # Skip tags and empty lines
        if ($line_text | str starts-with "%") or ($line_text | str trim | is-empty) {
            continue
        }

        # Description line (starts with #)
        if ($line_text | str starts-with "#") {
            $current_description = ($line_text | str replace "^# *" "" | str trim)
        } else if (not ($line_text | str trim | is-empty)) and (not ($current_description | is-empty)) {
            # Command line (non-empty line after a description)
            let command = ($line_text | str trim)

            # Filter by query if provided
            let matches = if ($query | is-empty) {
                true
            } else {
                (($current_description | str contains -i $query) or ($command | str contains -i $query) or ($cheatsheet_name | str contains -i $query))
            }

            if $matches {
                $results = ($results | append [{
                    cheatsheet: $cheatsheet_name
                    description: $current_description
                    command: $command
                    file: ($file | path basename)
                    file_path: $file
                    line: $line_num
                }])
            }

            $current_description = ""
        }
    }

    $results
}

# Check if cheatsheets directory exists
if not ($cheats_path | path exists) {
    print $"Error: Cheatsheets directory not found: ($cheats_path)"
    exit 1
}

# Parse all .cheat files
let all_results = (glob ($cheats_path | path join "*.cheat") | each { |file|
    parse-cheat-file $file
} | flatten)

# Output results in format: cheatsheet|description|command|file|line
$all_results | each { |entry|
    $"($entry.cheatsheet)|($entry.description)|($entry.command)|($entry.file_path)|($entry.line)"
} | sort
