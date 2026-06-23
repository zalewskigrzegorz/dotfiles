# mise task shortcuts for nushell.
#
# Repos like REDACTED_ORG/REDACTED_ORG define `[shell_alias]` in mise.toml (up, down,
# install, build → `mise run <task>`). mise's `hook-env` injects those as real
# shell aliases for bash/zsh/fish, but the nushell hook-env output drops them
# entirely — so in nu the bare `up`/`down`/… never get defined. These static
# aliases replicate what bash/zsh devs get automatically. They only do anything
# inside a repo whose mise.toml declares the matching task; elsewhere `mise run`
# just errors, same as a typo.

alias up = mise run up
alias down = mise run down
alias install = mise run install
alias build = mise run build
