---
paths:
  - "scriptc/workctl.ts"
  - "dot_config/tuios/**"
  - "dot_config/private_gh-dash/**"
  - "dot_config/nushell/autoload/tuios.nu"
  - "bin/pr-eyes"
  - "bin/build-gh-dash"
  - "run_onchange_after_46-pr-eyes-launchd.sh.tmpl"
---

# tuios worktrees: workctl, gh-dash

- **Every gh-dash `command:` is one shell-agnostic command.** gh-dash runs it through `$SHELL -c`, nushell in a tuios pane, so `cd …`, `;`, `&&`, `2>/dev/null` parse-error before running. Pass paths as flags (`workctl --repo-path …`). Lines `workctl` runs through `nu -e` follow `agent-rules/zsh-bash-tool.md` (`sh -c '…'`).
- **git `fsmonitor--daemon` leaks per worktree** (63 strays once; a leftover made `work rm` fail with `fsmonitor--daemon is already running`). `workctl rm` runs `git fsmonitor--daemon stop` first; `core.fsmonitor` is off for plugin and temp repos via the `includeIf` file `~/.config/git/no-fsmonitor`.
- **A worktree dir holding only `.claude/skills/` is a `bin/sync` husk** (stage 30 placed skills while `work rm` deleted the tree). `workctl rm` sweeps husks under the same `flock` as stage 30: just run `work rm` again, no manual `rm -rf`.
- **Branch pickers exclude any branch checked out in another worktree, root included**; `git worktree add` refuses it (picking `main` gave a raw JSON error, ~130 calls). Picking `main` is the regression case after touching the picker.
- **"Dodaj tool" beside a PR-picker screenshot = a new menu row** in `scriptc/workctl.ts` with an existing native command (`why-review`) as action, not a standalone command.
- **A picker row that prints a report waits for Enter** before the menu returns, or fzf's repaint wipes it (`2d37b11`). Test new rows in the live picker, not only headless.
- **`tuios new --detach` always opens one shell window** (even with `startup.open_default_window = false`) and nothing swaps its process. Typing into it works (`tuios-config.md`) but Greg rejected the risk: claude opens on workspace 2. Test on a scratch daemon: `XDG_CONFIG_HOME=<scratch> tuios new x --detach --server x`, then `tuios kill-server --server x`.
- **A tuios popup on an empty workspace starts in `~`** (`prefix+d` / `workctl rm --self` said `not inside a worktree`, 30c41c3e). Popup-bound commands find their worktree by `TUIOS_SESSION`, never `PWD`; pools are `TREE_ROOT`, `LEGACY_TREE_ROOT`, `TUIOS_TREE_ROOT`. Run a new key's command once headless from `~` with `TUIOS_SESSION` set before describing it.
- **The 👀 block in the gh-dash PR preview needs four parts** (536b9fd3): `bin/pr-eyes refresh` filling `~/.cache/pr-eyes.json`, the patched gh-dash from `bin/build-gh-dash`, the stage 46 `com.greg.pr-eyes` LaunchAgent (every 10 min), and `ctrl+e` (`pr-eyes refresh --force`). The build pins the extension (`ispinned: true`) so `gh extension upgrade --all` skips it; an upgrade that replaced it anyway (v4.26.3, 2026-11-17) dropped the patch → `bin/build-gh-dash` again, it builds the installed tag. Empty block → check: cache fresh, `launchctl list | rg pr-eyes`, running `gh-dash` is the patched build.
