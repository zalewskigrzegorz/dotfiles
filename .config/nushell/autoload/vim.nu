# Vim/Neovim - Editor tools and file selection

# Smart file picker with fzf and tmux integration
def v [] {
    fd --max-depth 5 --type f --hidden --exclude .git --exclude node_modules --exclude target --exclude build 
    | fzf-tmux -p 
    | if ($in | is-empty) { "" } else { nvim $in }
}

# Vim aliases
alias vim = nvim
alias vi = nvim

# Custom fzf command
def f [
    ...args: any  # All arguments passed to fzf
] {
    ^fzf ...$args
}

# Shortcuts helper using navi
alias n = navi 