# Carapace - Enhanced completions
# Provides better command completions for various CLI tools.
#
# NOTE: Use path-assignment / `merge`, NEVER `$env.config = {...}` — bare `=`
# replaces the whole record and wipes defaults + everything that loaded before
# this file (history settings from config.nu, hooks, cursor_shape, table style,
# etc.). Old version of this file did that and silently reset half the config.

# LS_COLORS for file styling (using vivid)
$env.LS_COLORS = (vivid generate dracula)

let carapace_completer = {|spans|
    carapace $spans.0 nushell ...$spans | from json
}

# Top-level toggles — merge shallowly into the existing config.
$env.config = ($env.config | merge {
    show_banner: false
    buffer_editor: "nvim"
})

# Completions block — assign each leaf so we don't clobber any sibling keys
# nushell may add to `completions` between releases.
$env.config.completions.case_sensitive = false
$env.config.completions.quick = true
$env.config.completions.partial = true
$env.config.completions.algorithm = "fuzzy"
$env.config.completions.external.enable = true
$env.config.completions.external.max_results = 100
$env.config.completions.external.completer = $carapace_completer