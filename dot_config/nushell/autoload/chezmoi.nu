# chezmoi wrapper — strip macOS Tahoe libsystem_malloc spam from stderr.
#
# Background: macOS 26.x prints `nu(PID) MallocStackLogging: can't turn off
# malloc stack logging because it was not enabled.` on every nu subprocess
# exit. nushell 0.113.1 has no fix yet. The baseline env var in env.nu.tmpl
# catches most cases; this wrapper is the belt-and-suspenders for chezmoi
# specifically — it spawns enough short-lived helpers during apply that the
# warning leaks through in rare cases.
#
# Implementation: buffer stderr via `complete`, filter the noise line, re-emit
# stdout verbatim and cleaned stderr. Preserves exit code. Buffers output, so
# you see results after the command finishes — fine for chezmoi (usually fast).

def --wrapped chezmoi [...rest] {
    let r = (do { ^chezmoi ...$rest } | complete)
    if not ($r.stdout | is-empty) {
        print -n $r.stdout
    }
    let clean_err = (
        $r.stderr
        | lines
        | where {|l| not ($l | str contains "MallocStackLogging:")}
        | str join (char nl)
    )
    if not ($clean_err | is-empty) {
        print -e $clean_err
    }
    if $r.exit_code != 0 {
        exit $r.exit_code
    }
}

# nvim-sync — re-capture LazyVim extras + plugin lockfile into the chezmoi
# source after a :Lazy update / :LazyExtras on this machine, then commit so the
# change reaches other machines (lab) on the next `chezmoi update`.
# Both files are chezmoi-managed (dropped the create_ prefix 2026-06-13), so the
# live files LazyVim writes are invisible to chezmoi until re-added by hand.
def nvim-sync [] {
    chezmoi re-add ~/.config/nvim/lazyvim.json ~/.config/nvim/lazy-lock.json
    git -C ~/Code/dotfiles add dot_config/nvim/lazyvim.json dot_config/nvim/lazy-lock.json
    let staged = (git -C ~/Code/dotfiles diff --cached --name-only | lines | length)
    if $staged == 0 {
        print "nvim state already in sync — nothing to commit."
        return
    }
    git -C ~/Code/dotfiles commit -m "chore(nvim): sync lazyvim extras + lock 🔄"
    print "✅ nvim re-added + committed. Run `git -C ~/Code/dotfiles push` when ready, then `chezmoi update` on the lab."
}
