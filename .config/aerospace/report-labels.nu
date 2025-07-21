#!/usr/bin/env nu

def extract_status_label [status_string: string] {
    # Handle different possible formats of StatusLabel
    try {
        # Try quoted label first: label="some text"
        let quoted_matches = ($status_string | parse --regex 'label="([^"]*)"')
        if ($quoted_matches | length) > 0 {
            let label = ($quoted_matches | get 0.capture0)
            if $label != "" {
                return $label
            }
        }
        
        # Try unquoted label: label=sometext (no spaces)
        let unquoted_matches = ($status_string | parse --regex 'label=([^\s}]+)')
        if ($unquoted_matches | length) > 0 {
            let label = ($unquoted_matches | get 0.capture0)
            if $label != "" {
                return $label
            }
        }
        
    } catch {
        return null
    }
    return null
}

def main [] {
    print "Starting app status monitor (handles any text labels)..."
    
    loop {
        try {
            let apps_with_status = (
                aerospace list-windows --all --json 
                | from json 
                | select app-name 
                | uniq-by app-name
                | each { |row| 
                    try {
                        let info = (lsappinfo info -only StatusLabel $row.app-name)
                        {app: $row.app-name, status: $info}
                    } catch {
                        {app: $row.app-name, status: ""}
                    }
                }
            )
            
            $apps_with_status | each { |app|
                let label = (extract_status_label $app.status)
                
                if $label != null and $label != "" {
                    try {
                        # Escape any special characters in the label for shell safety
                        let safe_label = ($label | str replace -a '"' '\"')
                        
                        sketchybar --trigger app_statusLabel $"appid=($app.app)" $"label=($safe_label)"
                        print $"✓ Sent: ($app.app) -> '($label)'"
                    } catch {
                        print $"✗ Failed to send to sketchybar for ($app.app)"
                    }
                }
            }
            
        } catch { |e|
            print $"Error in main loop: ($e.msg)"
        }
        
        sleep 60sec
    }
}
