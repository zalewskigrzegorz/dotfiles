# chezmoi — one entry point: `bin/sync`.
#
# `chezmoi` is aliased to `sync` so it does not matter which one you type. The
# alias resolves through PATH, where env.nu prepends this repo's bin/ ahead of
# /bin/sync (the BSD disk-flush utility) — on the lab the same name lands on the
# chezmoi-applied ~/bin/sync. Never hardcode ~/Code/dotfiles/bin/sync here: the
# lab has no checkout of this repo.
#
# What bin/sync adds, and why the bare binary is not enough:
#   * OP_SERVICE_ACCOUNT_TOKEN — interactive shells deliberately do NOT export it
#     (env.nu.tmpl explains: a set token makes `op` ignore the desktop app, so
#     `op item create` would run against the read-only service account). chezmoi
#     needs it to render onepasswordRead templates, and without it EVERY secret
#     falls back to interactive `op` and blocks until the approval timeout — once
#     per secret. A dozen secrets in, `chezmoi apply` looks hung for a quarter of
#     an hour.
#   * --force on apply/update — otherwise chezmoi stops at "<target> has changed
#     since chezmoi last wrote it?" for each externally-modified target. With ~800
#     directories drifting on mode alone that is unanswerable in practice, and the
#     raw-mode read it uses for the y/n leaves ONLCR off, so every later line of
#     output staircases. The repo is the source of truth; the settings-drift-check
#     SessionStart hook warns before a live edit gets discarded, and bin/audit-drift
#     is the review step.
# Everything other than apply/update passes straight through, no --force — so
# `chezmoi diff` / `status` / `re-add` behave exactly as documented.
#
# THERE USED TO BE A `def --wrapped chezmoi` HERE. Do not bring it back. It existed
# to filter macOS Tahoe's `MallocStackLogging:` spam, which env.nu.tmpl:26 already
# kills at the source (`hide-env -i MallocStackLogging`) — measured 2026-08-01: 0
# spam lines across 20 invocations without it. What it did still do was buffer
# output through `complete`, which made chezmoi's y/n prompt invisible: the command
# blocked on stdin with nothing on screen and looked hung forever. Filtering
# nothing at the cost of a silent deadlock.
alias chezmoi = sync

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
