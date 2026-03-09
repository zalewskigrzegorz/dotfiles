#!/usr/bin/env nu

# Kill watcher and sketchybar first, then aerospace; aerospace after-startup will start watcher + sketchybar again
print "🔄 Stopping services..."
try { ^killall -9 sketchybar-watcher } catch { print "No sketchybar-watcher process found" }
try { ^killall -9 sketchybar } catch { print "No sketchybar process found" }
try { ^killall -9 borders } catch { print "No borders process found" }

print "⏳ Waiting for processes to stop..."
sleep 2sec

print "🚀 Restarting aerospace..."
try {
    try { ^killall -9 AeroSpace } catch { print "No AeroSpace process found" }
    sleep 1sec
    ^open -a AeroSpace
    print "✅ Aerospace restart initiated"
} catch {
    print "❌ Failed to restart aerospace"
    exit 1
}

# Aerospace after-startup-command runs sketchybar-watcher then sketchybar
print "⏳ Waiting for startup commands..."
sleep 4sec

print "🔍 Checking sketchybar and watcher..."
try {
    let watcher_count = (^ps aux | ^grep "sketchybar-watcher" | ^grep -v grep | ^wc -l | str trim | into int)
    let sketchybar_count = (^ps aux | ^grep "sketchybar" | ^grep -v grep | ^grep -v "sketchybar-watcher" | ^wc -l | str trim | into int)
    if $sketchybar_count == 0 {
        print "🔧 Starting sketchybar manually..."
        ^sketchybar &
        sleep 1sec
    }
    if $watcher_count == 0 {
        print "🔧 Starting sketchybar-watcher manually..."
        ^$env.HOME/Code/dotfiles/bin/sketchybar-watcher/sketchybar-watcher &
        sleep 1sec
    }
    print "✅ Sketchybar and watcher running"
} catch {
    print "❌ Error checking status"
}

print "🎉 Restart complete!"