#!/usr/bin/env nu

# Kill existing processes
print "🔄 Stopping services..."
try { ^killall -9 sketchybar } catch { print "No sketchybar process found" }
try { ^killall -9 borders } catch { print "No borders process found" }  
try { ^killall -9 svim } catch { print "No svim process found" }

# Wait a moment for processes to fully terminate
print "⏳ Waiting for processes to stop..."
sleep 2sec

# Restart aerospace (this should trigger sketchybar via after-startup-command)
print "🚀 Restarting aerospace..."
try {
    # Kill aerospace if running
    try { ^killall -9 AeroSpace } catch { print "No AeroSpace process found" }
    sleep 1sec
    
    # Start aerospace again
    ^open -a AeroSpace
    print "✅ Aerospace restart initiated"
} catch {
    print "❌ Failed to restart aerospace"
    exit 1
}

# Wait for aerospace to start and trigger its startup commands
print "⏳ Waiting for startup commands..."
sleep 4sec

# Check if sketchybar started and start it manually if needed
print "🔍 Checking sketchybar status..."
try {
    let sketchybar_count = (^ps aux | ^grep "sketchybar" | ^grep -v grep | ^wc -l | str trim | into int)
    if $sketchybar_count == 0 {
        print "🔧 Starting sketchybar manually..."
        ^sketchybar &
        sleep 2sec
        
        let check_again = (^ps aux | ^grep "sketchybar" | ^grep -v grep | ^wc -l | str trim | into int)
        if $check_again > 0 {
            print "✅ Sketchybar started successfully"
        } else {
            print "❌ Failed to start sketchybar"
        }
    } else {
        print "✅ Sketchybar is already running"
    }
} catch {
    print "❌ Error checking sketchybar status"
}

print "🎉 Restart complete!"