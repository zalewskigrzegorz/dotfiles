# Starship - Cross-shell prompt
# Provides beautiful and informative shell prompt with git info, status codes, etc.

# Set starship shell environment
$env.STARSHIP_SHELL = "nu"

# Create the left prompt function using starship
def create_left_prompt [] {
    starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}

# Create the right prompt — cmd_duration + time. Without this, starship's
# `right_format` block is never rendered in nu.
def create_right_prompt [] {
    starship prompt --right --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}

# Configure nushell prompt to use starship
$env.PROMPT_COMMAND = { || create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = { || create_right_prompt }

# starship's `[character]` module renders the prompt symbol. Leave nu's
# PROMPT_INDICATOR empty so we don't double-print.
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""
$env.PROMPT_MULTILINE_INDICATOR = "├─ "

# Transient prompt uses starship's `[character]` only, via --profile transient
def create_transient_prompt [] {
    starship prompt --profile transient
}

$env.TRANSIENT_PROMPT_COMMAND = { || create_transient_prompt }
$env.TRANSIENT_PROMPT_INDICATOR = ""
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = ""
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = ""
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""
