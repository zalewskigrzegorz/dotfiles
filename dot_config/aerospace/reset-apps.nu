#!/usr/bin/env nu
# Moves apps to their assigned workspaces. Must match aerospace.toml on-window-detected rules.

let windows = aerospace list-windows --all --json | from json

$windows | where app-name =~ "(?i)discord|slack|chatmate|whatsapp|^messages$|facetime"
| each { |win| aerospace move-node-to-workspace chat --window-id $win.window-id }

$windows | where app-name =~ "(?i)comet|safari|google chrome|^zen$"
| each { |win| aerospace move-node-to-workspace web --window-id $win.window-id }

$windows | where app-name =~ "(?i)cursor|^code$|vscode|visual studio code|datagrip|claude|^zed$|docker desktop|beyond compare"
| each { |win| aerospace move-node-to-workspace code --window-id $win.window-id }

$windows | where app-name =~ "(?i)ghostty|^terminal$|iterm|kitty"
| each { |win| aerospace move-node-to-workspace term --window-id $win.window-id }

$windows | where app-name =~ "(?i)canary mail|spark mail|^mail$"
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }

$windows | where app-name =~ "(?i)notion calendar|fantastical|timing"
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }

$windows | where app-name =~ "(?i)^calendar$"
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }

$windows | where { |w| ($w.app-name | str downcase) =~ "notion" and ($w.app-name | str downcase) !~ "notion calendar" }
| each { |win| aerospace move-node-to-workspace notes --window-id $win.window-id }

$windows | where app-name =~ "(?i)spotify|endel|^vlc$|replay"
| each { |win| aerospace move-node-to-workspace media --window-id $win.window-id }

$windows | where app-name =~ "(?i)noteplan|obsidian|^notes$|drafts|reminders|pages creator studio|pencil|expressions"
| each { |win| aerospace move-node-to-workspace notes --window-id $win.window-id }

$windows | where app-name =~ "(?i)^firefox$|firefox developer edition|insomnia|rapidapi|proxyman|chipmunk"
| each { |win| aerospace move-node-to-workspace test --window-id $win.window-id }

$windows | where app-name =~ "(?i)cleverpdf|remarkable|stream deck|bazecor|logioptionsplus|kde connect|poly studio|qflipper|insta360|steam link|wifi explorer|istat menus|activity monitor|cleanmymac|google drive|google docs|google sheets|google slides|the unarchiver|path finder|upscayl"
| each { |win| aerospace move-node-to-workspace misc --window-id $win.window-id }
