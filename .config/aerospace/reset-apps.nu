#!/usr/bin/env nu

let windows = aerospace list-windows --all --json | from json

let windows = aerospace list-windows --all --json | from json

$windows 
| where app-name =~ "(?i)discord|slack|chatmate" 
| each { |win| aerospace move-node-to-workspace chat --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)arc" 
| each { |win| aerospace move-node-to-workspace web --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)cursor|code|vscode" 
| each { |win| aerospace move-node-to-workspace code --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)ghostty|terminal" 
| each { |win| aerospace move-node-to-workspace term --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)notion calendar" 
| each { |win| aerospace move-node-to-workspace cal --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)canary mail" 
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)spark mail" 
| each { |win| aerospace move-node-to-workspace mail --window-id $win.window-id }


$windows 
| where app-name =~ "(?i)spotify" 
| each { |win| aerospace move-node-to-workspace media --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)noteplan" 
| each { |win| aerospace move-node-to-workspace notes --window-id $win.window-id }

$windows 
| where app-name =~ "(?i)firefox" 
| each { |win| aerospace move-node-to-workspace test --window-id $win.window-id }
