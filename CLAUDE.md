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
