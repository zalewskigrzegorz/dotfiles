#!/usr/bin/env nu

# Get app notifications for sketchybar
# Output format: app_name:notification_indicator

aerospace list-windows --all --json | from json | select app-name | each { |row|
    let info = (lsappinfo info -only StatusLabel $row.app-name)
    let label = ($info | str replace --regex '.*"label"=([^\s}\]]+).*' '$1' | str trim)
    if $label != 'kCFNULL' and $label != '"StatusLabel"=[ NULL ]' and $label != '' {
        $"($row.app-name):($label)"
    }
} | compact | str join "\n" 