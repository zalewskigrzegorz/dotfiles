# Basti - Bastion host connection manager
# Provides completions for basti commands and connection targets

# Custom completion for basti connect command
def "nu-complete basti connections" [] {
    let config = (pwd | path join ".basti.yaml")
    if ($config | path exists) {
        open $config
        | get connections
        | columns
        | each { |it| {value: $it} }
    } else {
        []
    }
}

# Custom completion for basti connect targets
def "nu-complete basti-targets" [] {
    if (not ($".basti.yaml" | path exists)) { return [] }

    open .basti.yaml
    | get connections
    | columns
}

# Define available basti commands
def "nu-complete basti-commands" [] {
    ['connect', 'init', 'cleanup']
}

# Define the basti command with correct subcommands
export extern "basti" [
    command: string@"nu-complete basti-commands"  # The command to run
    target?: string@"nu-complete basti-targets"   # Target for connect command
    --help(-h)                                    # Show help
    --version(-v)                                 # Show version
] 