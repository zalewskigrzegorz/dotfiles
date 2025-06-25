

# Editor
$env.EDITOR = "nvim"
$env.VISUAL = "nvim"
$env.SHELL = "/opt/homebrew/bin/nu"


# Config settings
$env.config.show_banner = false
$env.config.buffer_editor = "nvim"

# Load private environment variables from autoload directory
# Note: Files in ~/.config/nushell/autoload/ will be automatically sourced
use std "path add"

# PATH configurations  
let home = $env.HOME
use std "path add"
path add $"($home)/.asdf/shims"
path add $"($home)/.asdf/bin"
path add $"($home)/Library/Application Support/carapace/bin"
path add $"($home)/Library/pnpm"
path add "/opt/homebrew/opt/asdf/libexec/bin"
path add "/opt/homebrew/opt/openjdk/bin"
path add "/opt/homebrew/bin"

# $env.PATH = ($env.PATH | split row (char esep) | prepend [
#     "/opt/homebrew/opt/asdf/libexec/bin"
#     $"($home)/.asdf/shims"
#     $"($home)/Library/Application Support/carapace/bin"
#     $"($home)/.asdf/bin"
#     $"($home)/Library/pnpm"
#     "/opt/homebrew/opt/openjdk/bin"
#     "/opt/homebrew/bin"
#     "/opt/homebrew/opt/mysql-client/bin"
#     "/usr/local/bin"
#     "/System/Cryptexes/App/usr/bin"
#     "/usr/bin"
#     "/bin"
#     "/usr/sbin"
#     "/sbin"
#     "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin"
#     "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin"
#     "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin"
#     "/Library/Apple/usr/bin"
# ])

# PNPM config
$env.PNPM_HOME = ($env.HOME | path join "Library/pnpm")
# Starship config
$env.STARSHIP_CONFIG = ($env.HOME | path join ".config/starship" "starship.toml")

# Tmux config
$env.TMUX_CONFIG = ($env.HOME | path join ".config/tmux" "tmux.conf")

# Carapace config
$env.CARAPACE_BRIDGES = 'zsh,fish,bash'

# Set nvim to use nushell
$env.NVIM_SHELL = "/opt/homebrew/bin/nu"