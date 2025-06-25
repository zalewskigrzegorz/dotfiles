# macOS XDG Environment Fix
# Generates a LaunchAgent plist to set XDG environment variables system-wide
# This fixes apps that don't respect XDG config directories on macOS

def main [] {
    let home = $env.HOME
    let plist_dir = ($home | path join "Library" "LaunchAgents")
    let plist_file = ($plist_dir | path join "me.greg.environment.plist")
    
    # Ensure LaunchAgents directory exists
    mkdir $plist_dir
    
    # Generate the plist content
    let plist_content = $'<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>me.greg.environment</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>
            launchctl setenv XDG_CONFIG_HOME ($home)/.config &&
            launchctl setenv XDG_CACHE_HOME ($home)/.cache &&
            launchctl setenv XDG_DATA_HOME ($home)/.local/share &&
            launchctl setenv XDG_STATE_HOME ($home)/.local/state &&
            launchctl setenv XDG_RUNTIME_DIR ($home)/.local/run &&
            launchctl setenv XDG_BIN_HOME ($home)/.local/bin
        </string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ServiceIPC</key>
    <false/>
</dict>
</plist>'
    
    # Write the plist file
    $plist_content | save --force $plist_file
    
    print $"✅ Created LaunchAgent plist: ($plist_file)"
    
    # Check if already loaded and unload if necessary
    let is_loaded = (launchctl list | str contains "me.greg.environment")
    if $is_loaded {
        print "🔄 Unloading existing LaunchAgent..."
        launchctl unload $plist_file
    }
    
    # Load the LaunchAgent
    print "🚀 Loading LaunchAgent..."
    launchctl load $plist_file
    
    # Verify it's loaded
    let verify_loaded = (launchctl list | str contains "me.greg.environment")
    if $verify_loaded {
        print "✅ LaunchAgent successfully loaded!"
        print "🎉 XDG environment variables are now set system-wide"
        print ""
        print "📝 Note: You may need to restart GUI applications for them to pick up the new environment"
    } else {
        print "❌ Failed to load LaunchAgent. Try manually:"
        print $"   launchctl load ($plist_file)"
    }
    
    print ""
    print "🗑️  To remove later:"
    print $"   launchctl unload ($plist_file) && rm ($plist_file)"
}