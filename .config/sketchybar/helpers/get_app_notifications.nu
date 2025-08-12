#!/usr/bin/env nu

# Get app notifications for sketchybar
# Output format: app_name:notification_indicator

# Check if aerospace is running first
if (which aerospace | is-empty) {
    exit 1
}

try {
    let windows = (aerospace list-windows --all --json)
    if ($windows | is-empty) or ($windows | str trim) == "" {
        exit 0
    }
    
    $windows | from json | select app-name | each { |row|
        try {
            let info = (lsappinfo info -only StatusLabel $row.app-name)
            let label = ($info | str replace --regex '.*"label"=([^\s}\]]+).*' '$1' | str trim)
            if $label != 'kCFNULL' and $label != '"StatusLabel"=[ NULL ]' and $label != '' {
                $"($row.app-name):($label)"
            }
        } catch {
            # Silently ignore apps that can't be queried
            null
        }
    } | compact | str join "\n"
} catch {
    # If aerospace fails, exit silently
    exit 0
} 