# Simple wrapper for terminal-notifier
# See: https://github.com/ghostty-org/ghostty/discussions/3555
def notify [
    message: string  # Message to display
    --title (-t): string = ""  # Optional title
    --sound (-s): string = "Funk"  # Sound effect (Funk, Ping, Hero, etc)
] {
    let title_args = if ($title | is-empty) { [] } else { ["-title" $title] }
    run-external "terminal-notifier" "-message" $message "-sound" $sound ...$title_args
}

# Notify for long-running commands (over 10 seconds)
let dur_limit = 10sec

# Initialize tracking variables
$env.NOTIFY_START_TIME = (date now)
$env.NOTIFY_CMD = ""

# Set up hooks
$env.config = ($env.config 
    | upsert hooks.pre_execution [{||
        $env.NOTIFY_START_TIME = (date now)
        $env.NOTIFY_CMD = (commandline)
    }]
    | upsert hooks.pre_prompt [{||
        let duration = ((date now) - $env.NOTIFY_START_TIME)
        if $duration > $dur_limit {
            let status = if $env.LAST_EXIT_CODE == 0 { "✔︎" } else { "✖︎" }
            notify -t (pwd) -s Ping $"($status) ($env.NOTIFY_CMD)"
        }
    }])