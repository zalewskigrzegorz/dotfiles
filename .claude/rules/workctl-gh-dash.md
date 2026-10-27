---
paths:
  - "scriptc/workctl.ts"
  - "dot_config/tuios/**"
  - "dot_config/private_gh-dash/**"
  - "dot_config/nushell/autoload/tuios.nu"
---

# tuios worktrees: workctl, gh-dash

- **Every gh-dash `command:` must be one shell-agnostic command.** gh-dash runs custom keybinding commands through `$SHELL -c`, and in a tuios pane `$SHELL` is nushell — `cd …`, `;`, `&&`, `2>/dev/null` and other POSIX-only syntax parse-error and exit 1 *before* the command runs. Pass paths as flags instead (`workctl --repo-path …`, not `cd <path>; workctl`). Broke the `T` keybinding in `dot_config/private_gh-dash/config.yml.tmpl` (fixed 2026-09-22). The same applies to every line `workctl` runs through `nu -e` (the claude, agent and bootstrap tabs) — wrap POSIX syntax as `sh -c '…'` (fixed in `workctl` 2026-09-23).
- **git `fsmonitor--daemon` leaks per worktree.** Every worktree and every nvim plugin repo starts its own daemon; 63 stray ones were found on 2026-09-25, and one left on a removed worktree made `work rm` fail with `fatal: fsmonitor--daemon is already running`. `workctl rm` runs `git fsmonitor--daemon stop` first (safe when none is running), and `core.fsmonitor` is off for plugin and temp repos through the `includeIf` file `~/.config/git/no-fsmonitor`.
- **A worktree dir holding only `.claude/skills/` is a `bin/sync` husk.** Stage 30 placed work skills into a tree that `work rm` was deleting at the same moment, so the dir outlived its `.git` and is missing from `git worktree list` (2026-10-06). `workctl rm` sweeps husks (0c2c9d0) and takes the same `flock` as stage 30's placement, so just run `work rm` again; no manual `rm -rf`.
- **`workctl` branch pickers must exclude any branch checked out in another worktree, the root checkout included.** `git worktree add` refuses it, and picking `main` from the list produced a raw JSON error that took ~130 tool calls to diagnose (2026-09-24). Selecting `main` is the regression case to try after touching the picker.
- **"Dodaj tool" next to a screenshot of the PR picker means a new menu row** in `scriptc/workctl.ts`, with an existing native command (`why-review`) as its action, not a standalone command (2026-10-23: "NIE WIDZE").
- **A picker row that prints a report waits for Enter** before the menu comes back, or fzf's repaint wipes the output (`fe60887`). Test a new row in the live picker, not only headless.
