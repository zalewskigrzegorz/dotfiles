# Logs - PM2 log parsing and management
# Provides functions to parse and analyze PM2 application logs
#
# How to view logs:
#   pm2logs              # parsed stdout (default: api)
#   pm2logs portal        # parsed stdout for process "portal"
#   pm2errors             # parsed stderr (default: api)
#   apilogs / apierrors   # same as pm2logs api / pm2errors api (no arguments)
#   pm2-logs              # only returns file paths { out, error }, no content

# Completion: list PM2 process names (same source as television/cable/pm2.toml)
def "nu-complete pm2-processes" [] {
    let path_additions = [
        ($env.HOME | path join ".asdf" "shims"),
        ($env.HOME | path join "Library" "pnpm")
    ]
    let old_path = $env.PATH
    $env.PATH = ($path_additions | append $env.PATH)
    let result = (do { ^pnpm pm2 jlist } | complete)
    $env.PATH = $old_path
    if $result.exit_code != 0 {
        return []
    }
    try {
        $result.stdout | from json | get name
    } catch {
        []
    }
}

# Get PM2 log file paths for a process (default: api)
def pm2-logs [process: string@"nu-complete pm2-processes" = "api"] {
    let base = ($env.HOME | path join ".pm2" "logs" $process)
    {
        out: ($base + "-out.log"),
        error: ($base + "-error.log")
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

# Get parsed output logs from a PM2 process (default: api)
export def pm2logs [
    process?: string@"nu-complete pm2-processes" = "api"
] {
    pm2-parse ((pm2-logs $process).out)
}

# Get parsed error logs from a PM2 process (default: api)
export def pm2errors [
    process?: string@"nu-complete pm2-processes" = "api"
] {
    pm2-parse ((pm2-logs $process).error)
}

# Aliases for backward compatibility
export def apilogs [] {
    pm2logs "api"
}

export def apierrors [] {
    pm2errors "api"
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
