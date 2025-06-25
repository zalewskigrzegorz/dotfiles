# PNPM - Package manager for Node.js

# PNPM scripts and commands autocomplete
def "nu-complete pnpm-commands-and-scripts" [] {
  # A comprehensive list of pnpm commands
  let commands = [
    "add", "audit", "bin", "config", "dedupe", "deploy", "dlx", "exec", "explore",
    "help", "import", "init", "install", "link", "list", "outdated", "pack", "patch",
    "publish", "rebuild", "remove", "root", "run", "start", "store", "test", "unlink",
    "update", "why", "run-script", "i", "up", "rm", "un", "r", "prune", "serve",
    "licenses", "ls", "ll", "la", "fix", "setup", "completion"
  ]

  let scripts = if (ls package.json | is-empty) {
    []
  } else {
    open package.json | get scripts | columns
  }

  $commands | append $scripts
}

export extern "pnpm" [
  command?: string@"nu-complete pnpm-commands-and-scripts"
  --recursive(-r)  # Run the command for each project in the workspace
  --help(-h)       # Display help
  --filter(-F)     # Filter packages
]

# Alias for pnpm
alias p = pnpm 