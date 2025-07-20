# Carapace - Enhanced completions
# Provides better command completions for various CLI tools

# LS_COLORS for file styling (using vivid)
$env.LS_COLORS = (vivid generate dracula)
let carapace_completer = {|spans|
    carapace $spans.0 nushell ...$spans | from json
}

$env.config = {
    show_banner: false
    buffer_editor: "nvim"
    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
        external: {
            enable: true
            max_results: 100
            completer: $carapace_completer
        }
    }
}