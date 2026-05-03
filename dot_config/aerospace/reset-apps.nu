#!/usr/bin/env nu
# Moves apps to their assigned workspaces. Must match aerospace.toml on-window-detected rules.

let windows = aerospace list-windows --all --json | from json

$windows | where app-name =~ "(?i)discord|slack|chatmate"
| each { |win| aerospace move-node-to-workspace chat --window-id $win.window-id }

$windows | where app-name =~ "(?i)arc|comet"
| each { |win| aerospace move-node-to-workspace web --window-id $win.window-id }

$windows | where app-name =~ "(?i)cursor|code|vscode|datagrip"
| each { |win| aerospace move-node-to-workspace code --window-id $win.window-id }

$windows | where app-name =~ "(?i)ghostty|terminal"
| each { |win| aerospace move-node-to-workspace term --window-id $win.window-id }

$windows | where app-name =~ "(?i)canary mail|spark mail"
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }

$windows | where app-name =~ "(?i)notion calendar|fantastical"
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }

$windows | where app-name =~ "(?i)^calendar$"
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }

$windows | where { |w| ($w.app-name | str downcase) =~ "notion" and ($w.app-name | str downcase) !~ "notion calendar" }
| each { |win| aerospace move-node-to-workspace notes --window-id $win.window-id }

$windows | where app-name =~ "(?i)spotify|endel"
| each { |win| aerospace move-node-to-workspace media --window-id $win.window-id }

$windows | where app-name =~ "(?i)noteplan|obsidian"
| each { |win| aerospace move-node-to-workspace notes --window-id $win.window-id }

$windows | where app-name =~ "(?i)firefox"
| each { |win| aerospace move-node-to-workspace test --window-id $win.window-id }
