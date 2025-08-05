# Logs - PM2 log parsing and management
# Provides functions to parse and analyze PM2 application logs

# Get PM2 log file paths
def pm2-logs [] {
    {
        out: ($env.HOME + "/.pm2/logs/api-out.log"),
        error: ($env.HOME + "/.pm2/logs/api-error.log")
    }
}

# Parse PM2 log files for JSON entries
def pm2-parse [input: string] {
    open $input |
    lines |
    each { |line|
        if ($line | str starts-with "{") {
            try {
                $line | from json
            } catch {
                null
            }
        } else {
            null
        }
    } |
    compact
}

# Get parsed output logs from PM2
def apilogs [] {
    pm2-parse (pm2-logs).out
}

# Get parsed error logs from PM2
def apierrors [] {
    pm2-parse (pm2-logs).error
}

def "from safe-json" [] {
    lines | each { |line|
        let trimmed = $line | str trim
        if not ($trimmed | is-empty) and ($trimmed | str starts-with "{") {
            try {
                $trimmed | from json
            } catch {
                null
            }
        } else {
            null
        }
    } | compact
}
