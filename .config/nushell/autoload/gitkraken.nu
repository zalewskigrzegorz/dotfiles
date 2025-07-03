# GitKraken doesn't seem to like my environment, but these commands keep its power under closed in tmux session super handy for quick log grabing 

# Configuration
const KRAKEN_SESSION = "gitkraken"
const KRAKEN_PATH = "/Applications/GitKraken.app/Contents/MacOS/GitKraken"

# Helper to check if session exists
def session-exists [name: string] {
    (do { tmux has-session -t $name } | complete).exit_code == 0
}

# Helper to check if we're in tmux
def in-tmux [] {
    "TMUX" in $env
}

# Autocompletion with desciprtion for kraken command
def kraken-completions [] {
    [
        {
            value: "kill"
            description: "Kill GitKraken session"
        }
        {
            value: "attach"
            description: "Attach to GitKraken session"
        }
    ]
}

# Main kraken command
def kraken [
    action?: string@kraken-completions
] {
    match $action {
        "kill" => {
            if (session-exists $KRAKEN_SESSION) {
                tmux kill-session -t $KRAKEN_SESSION
                print "🗑️ GitKraken session killed"
            } else {
                print "❌ No GitKraken session running"
            }
        }
        "attach" => {
            # Auto-start if no session exists
            if not (session-exists $KRAKEN_SESSION) {
                print "🚀 Starting GitKraken session..."
                tmux new-session -d -s $KRAKEN_SESSION $KRAKEN_PATH
                sleep 2sec
            }
            
            if (in-tmux) {
                tmux switch-client -t $KRAKEN_SESSION
            } else {
                tmux attach-session -t $KRAKEN_SESSION
            }
        }
        null => {
            # Default: start if not running
            if (session-exists $KRAKEN_SESSION) {
                print "📎 GitKraken session already running"
                tmux send-keys -t $KRAKEN_SESSION $KRAKEN_PATH Enter
            } else {
                print "🚀 Starting GitKraken in new tmux session..."
                tmux new-session -d -s $KRAKEN_SESSION $KRAKEN_PATH
            }
            print "✅ GitKraken running in background"
        }
        _ => {
            print "Usage: kraken [kill|attach]"
            print "  kraken       - Start GitKraken (or restart if running)"
            print "  kraken kill  - Kill GitKraken session"
            print "  kraken attach - Attach to session (auto-starts if needed)"
        }
    }
}

