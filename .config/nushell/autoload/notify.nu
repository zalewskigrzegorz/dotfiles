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

# List of applications to exclude from notifications
# Add command names (or parts of commands) you don't want to be notified about
let notify_exclude_list = [
    "vim",
    "nvim",
    "nano",
    "emacs",
    "code",
    "cursor",
    "ssh",
    "tmux",
    "screen",
    "less",
    "more",
    "man",
    "htop",
    "top",
    "btop",
    "watch",
    "atuin",
    "nu",
    "lazygit",
    "lazydocker",
    "spf",
    "v"
]
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
            # Check if the command should be excluded from notifications
            let cmd_parts = ($env.NOTIFY_CMD | split row " ")
            let base_cmd = ($cmd_parts | first | path basename)
            
            let should_notify = not ($notify_exclude_list | any {|exclude| $base_cmd =~ $exclude})
            
            if $should_notify {
                let status = if $env.LAST_EXIT_CODE == 0 { "✔︎" } else { "✖︎" }
                notify -t (pwd) -s Ping $"($status) ($env.NOTIFY_CMD)"
            }
        }
    }])
