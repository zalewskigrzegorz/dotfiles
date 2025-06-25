# Starship - Cross-shell prompt
# Provides beautiful and informative shell prompt with git info, status codes, etc.

# Set starship shell environment
$env.STARSHIP_SHELL = "nu"

# Create the left prompt function using starship
def create_left_prompt [] {
    starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}

# Configure nushell prompt to use starship
$env.PROMPT_COMMAND = { || create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = ""

# TODO: find the way to use Nerd Font icons
$env.PROMPT_INDICATOR = "❯ "
$env.PROMPT_INDICATOR_VI_INSERT = "❯ "
$env.PROMPT_INDICATOR_VI_NORMAL = "❮ "
$env.PROMPT_MULTILINE_INDICATOR = "├─ "