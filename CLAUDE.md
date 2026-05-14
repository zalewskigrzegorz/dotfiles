# dotfiles

Personal dotfiles managed by [chezmoi](https://chezmoi.io). `chezmoi apply` must reproduce the full setup on a fresh machine.

## Hard rules

1. **All settings live here.** Every plugin, MCP server, skill, hook, permission, keybinding, brew formula, and tool config must be mirrored into this repo. If something only exists in `~/` and not under `~/Code/dotfiles/`, it is invisible to `chezmoi apply` and will not survive a reinstall.
2. **Commit directly to `master`.** No feature branches, no PRs — this is a personal repo. Push when ready.
3. **Add via chezmoi, not manual copy.** Use `chezmoi add ~/<path>` so the source naming (`dot_*`, `private_*`, `executable_*`, `.tmpl`) is correct.

## Source layout

- `dot_*` → `~/.* ` (e.g. `dot_claude/` → `~/.claude/`, `dot_config/` → `~/.config/`)
- `*.tmpl` → rendered by chezmoi (use for machine-specific or templated values)
- `private_*` → file mode 0600
- `executable_*` → file mode 0755
- `run_once_*` / `run_onchange_*` / `run_after_*` → chezmoi hooks (bootstrap scripts)
- `dot_Brewfile.tmpl` → brew bundle, auto-applied via `run_onchange` when changed

## Workflow

- Edit live config in `~/` then `chezmoi re-add` (or `chezmoi add` for new files), OR edit source under `~/Code/dotfiles/` then `chezmoi apply`.
- Verify with `chezmoi diff` before committing.
- Brewfile changes auto-run `brew bundle` via `run_onchange_after_10-brew-bundle.sh.tmpl`.

## Claude-specific

- Global Claude config lives in `dot_claude/` → `~/.claude/`:
  - `settings.json.tmpl` — main settings (templated for secrets)
  - `keybindings.json` — key bindings
  - `hooks/` — SessionStart, Stop, etc.
  - `output-styles/` — custom response styles
- Plugins/MCP/skills are declared in `agent-plugins/plugins.json.tmpl`, `nushell-mcp.json.tmpl`, and `run_onchange_after_3{0,1,2,3}-*.sh.tmpl` sync scripts.
- Anything installed via `/plugin install` or `claude mcp add` on a machine must be reflected in the relevant `.tmpl` so the next `chezmoi apply` reinstalls it.

## tmux + persistence

- **No auto-tmux on shell start.** `dot_config/nushell/autoload/ghostty.nu` and `ssh-tmux.nu` keep their auto-`exec tmux` / `exec sesh connect` blocks commented out. Start tmux manually (`tn` alias = `tmux new-session -s main`). Reason: multiple race / crash modes when auto-tmux fires during shell init (TTY race in Ghostty, `sesh connect` requires a session arg, restored panes spawn through wrappers).
- **`tmux-resurrect` + `tmux-continuum` are disabled** (plugin lines commented in `dot_config/tmux/tmux.conf`, plugin dirs removed). Restore reliably crashes the running tmux server in this setup — likely `switch-client` + `kill-session "0"` in `restore.sh` clashing with `default-command "exec nu"` and the TUI window wrappers. Re-enable only after that interaction is fixed.
- **Window wrappers** (`dot_config/nushell/autoload/zz-tmux-window-wrappers.nu`) spawn each TUI in its own tmux window with a nerd-font icon: `nvim`/`vim`/`vi`, `claude`, `lazygit`, `gh-dash`, `lazydocker`, `btop`. Use `\u{xxxx}` escapes so codepoints survive every edit; literal glyphs in source have been silently stripped before.

## Lab (`minis`, Debian) — connect & cold-start

- SSH alias: `ssh lab` (chezmoi-templated `~/.ssh/config`); fallback `ssh lab-via-ip` (192.168.50.10).
- **One-time terminfo install on each remote** so tmux/nvim accept `xterm-ghostty`:
  ```
  infocmp -x xterm-ghostty | ssh <host> -- tic -x -
  ```
- Lab login shell is `bash`, not nu. Either run `nu` after login or `chsh -s $(which nu)` (after adding nu to `/etc/shells`).
- **Pulling new dotfiles on lab from bash:** `chezmoi update` (runs `git pull` in `~/.local/share/chezmoi` + `chezmoi apply`). `~/Code/dotfiles` on lab is NOT a git checkout.
- `1Password CLI` on Linux is **not** in homebrew. Install via apt (commands in `dot_Brewfile.tmpl` comment under the Linux block).
- Accepted workflow: `tn` on mac → SSH from inside that tmux window → `nu` + `tn`/`ta` on lab. Two status bars (mac-tmux + lab-tmux nested), prefix is `Space`, send to inner tmux via `Space Space` (`bind-key ' ' send-prefix`).
