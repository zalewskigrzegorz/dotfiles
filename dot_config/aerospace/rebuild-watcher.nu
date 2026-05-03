#!/usr/bin/env nu
# Rebuild sketchybar-watcher and restart it
let watcher_dir = $env.HOME + "/Code/dotfiles/bin/sketchybar-watcher"
cd $watcher_dir
go build -o sketchybar-watcher .
try { ^killall -9 sketchybar-watcher } catch { }
^$watcher_dir/sketchybar-watcher >> $env.HOME/Code/dotfiles/logs/sketchybar-watcher.log 2>&1 &
