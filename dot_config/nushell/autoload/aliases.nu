# Quick shell aliases — single-letter shortcuts for high-frequency commands.
#
# `q` saves the slow `exit` typing. `lg` restores muscle memory from the older
# config (also flagged in the 2026-05-23 polish brainstorm). Other tool-specific
# aliases live in their own dedicated autoloads (vim.nu, tmux.nu, pnpm.nu …).

# exit the shell
alias q = exit
# open lazygit in the current repo
alias lg = lazygit

# Review working-tree changes on demand (one-shot `hunk diff`, no --watch) —
# e.g. before a commit. `work` no longer keeps a hunk --watch window open.
# Three names for the same thing; pick whichever sticks. (`git rv` = live watch.)

# zobacz zmiany w repo przed commitem (one-shot hunk diff)
alias zmiany = hunk diff
# review working-tree changes before commit (one-shot hunk diff)
alias changes = hunk diff
# hunk diff — review working-tree changes before commit (one-shot)
alias hd = hunk diff
