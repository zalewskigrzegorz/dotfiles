#!/usr/bin/env nu

let windows = aerospace list-windows --all --json | from json

let windows = aerospace list-windows --all --json | from json

$windows 
| where app-name =~ "(?i)discord|slack|chatmate" 
| each { |win| aerospace move-node-to-workspace comunication --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)arc" 
| each { |win| aerospace move-node-to-workspace web --window-id $win.window-id }


$windows 
| where app-name =~ "(?i)cursor|code|firefox|vscode" 
| each { |win| aerospace move-node-to-workspace code --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)ghostty|terminal" 
| each { |win| aerospace move-node-to-workspace terminal --window-id $win.window-id }


$windows 
| where app-name =~ "(?i)spotify" 
| each { |win| aerospace move-node-to-workspace media --window-id $win.window-id }