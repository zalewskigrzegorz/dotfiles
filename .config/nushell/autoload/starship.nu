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

# Create the transient (minimal) prompt shown on previous commands
# Uses only Starship's `character` module for a compact arrow
# Ref: https://www.nushell.sh/book/configuration.html#transient-prompt

def create_transient_prompt [] {
    ""
}

# Enable Nushell's transient prompt support
$env.TRANSIENT_PROMPT_COMMAND = { || create_transient_prompt }
$env.TRANSIENT_PROMPT_INDICATOR = "❯ "
$env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = "❯ "
$env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = "❮ "
# Blank to remove the tree icon on wrapped lines in command history
$env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = ""
