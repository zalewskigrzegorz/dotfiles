# Process Management Utilities
# Functions for managing and killing processes

# Kill all Vitest test runner processes
# Finds and kills all running Vitest processes that are consuming CPU
# Usage: kill-vitest
export def kill-vitest [] {
    print "Searching for Vitest processes..."
    
    # Use pgrep to find PIDs of processes containing "vitest" in command line
    let pids = (
        ^pgrep -f "vitest" 
        | lines 
        | each {|line| $line | into int }
    )
    
    if ($pids | is-empty) {
        print "✓ No Vitest processes found"
        return
    }
    
    # Get process details for display
    for $pid in $pids {
        let proc_info = (ps | where pid == $pid | first)
        if ($proc_info | is-not-empty) {
            print $"Found Vitest process: PID ($pid), CPU: ($proc_info.cpu)%, MEM: ($proc_info.mem)"
        }
    }
    
    # Kill all processes
    for $pid in $pids {
        try {
            kill -9 $pid
            print $"✓ Killed Vitest process (PID: $pid)"
        } catch {|err|
            let err_msg = try { $err.msg } catch { $err | describe }
            print $"✗ Failed to kill process PID ($pid): ($err_msg)"
        }
    }
    
    print "✓ Done"
}

# Kill processes by name pattern
# More flexible function to kill any process matching a pattern
# Usage: kill-process "vitest" or kill-process "node.*vitest"
export def kill-process [
    pattern: string  # Process name pattern to match
    --force (-f)  # Use SIGKILL (-9) instead of SIGTERM
] {
    print $"Searching for processes matching: ($pattern)"
    
    # Use pgrep to find PIDs matching the pattern
    let pids = (
        ^pgrep -f $pattern 
        | lines 
        | each {|line| $line | into int }
    )
    
    if ($pids | is-empty) {
        print $"✓ No processes found matching: ($pattern)"
        return
    }
    
    # Get process details for display
    let count = ($pids | length)
    let plural = if $count == 1 { "process" } else { "processes" }
    print $"Found ($count) ($plural):"
    for $pid in $pids {
        let proc_info = (ps | where pid == $pid | first)
        if ($proc_info | is-not-empty) {
            print $"  PID ($pid): ($proc_info.name), CPU: ($proc_info.cpu)%, MEM: ($proc_info.mem)"
        }
    }
    
    # Kill all processes
    for $pid in $pids {
        try {
            if $force {
                kill -9 $pid
            } else {
                kill -15 $pid
            }
            let sig_name = if $force { "SIGKILL" } else { "SIGTERM" }
            print $"✓ Sent ($sig_name) to process (PID: $pid)"
        } catch {|err|
            let err_msg = try { $err.msg } catch { $err | describe }
            print $"✗ Failed to kill process PID ($pid): ($err_msg)"
        }
    }
    
    print "✓ Done"
}

# Find high CPU processes
# Shows processes consuming significant CPU resources
# Usage: high-cpu [threshold]
export def high-cpu [
    threshold: float = 10.0  # CPU percentage threshold
] {
    print $"Finding processes with CPU > ($threshold)%..."
    
    ps 
    | where cpu > $threshold 
    | sort-by cpu --reverse 
    | select pid cpu mem name 
    | table
}

# Find high memory processes
# Shows processes consuming significant memory
# Usage: high-mem [threshold_mb]
# Note: Threshold is in MB (not percentage), default is 100 MB
export def high-mem [
    threshold_mb: float = 100.0  # Memory threshold in MB
] {
    let threshold_bytes = ($threshold_mb * 1024 * 1024 | into int)
    print $"Finding processes with memory > ($threshold_mb) MB..."
    
    ps 
    | where {|row| ($row.mem | into int) > $threshold_bytes }
    | sort-by {|row| $row.mem | into int } --reverse 
    | select pid cpu mem name 
    | table
}

# Monitor Vitest processes
# Watch for Vitest processes and optionally auto-kill them
# Usage: watch-vitest [--auto-kill]
export def watch-vitest [
    --auto-kill (-k)  # Automatically kill Vitest processes when found
] {
    print "Monitoring for Vitest processes..."
    print "Press Ctrl+C to stop"
    
    loop {
        let pids = (
            ^pgrep -f "vitest" 
            | lines 
            | each {|line| $line | into int }
        )
        
        if not ($pids | is-empty) {
            let count = ($pids | length)
            mut total_cpu = 0.0
            
            for $pid in $pids {
                let proc_info = (ps | where pid == $pid | first)
                if ($proc_info | is-not-empty) {
                    $total_cpu = $total_cpu + ($proc_info.cpu | into float)
                    print $"  PID ($pid): CPU ($proc_info.cpu)%, MEM ($proc_info.mem)"
                }
            }
            
            let plural = if $count == 1 { "process" } else { "processes" }
            print $"⚠️  Found ($count) Vitest ($plural) using ($total_cpu | math round --precision 1)% CPU"
            
            if $auto_kill {
                process kill-vitest
            }
        } else {
            print "✓ No Vitest processes running"
        }
        
        sleep 5sec
    }
}

