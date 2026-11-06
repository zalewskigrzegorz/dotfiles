# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/) and bootstrapped with Homebrew/Linuxbrew.

## Profiles

- `workstation` - macOS desktop/laptop with GUI apps, casks, HyprMac, SketchyBar, Zed and Claude config.
- `homelab` - headless Debian/Ubuntu with CLI and shell config only. No casks, GUI apps, fonts, window manager or status bar tooling.

The active profile is stored in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
profile = "homelab"
setapp = false
```

## Bootstrap

From this checkout:

```bash
./bootstrap.sh workstation
./bootstrap.sh homelab
```

On a new machine, set `DOTFILES_REPO` if the default SSH URL is not available:

```bash
DOTFILES_REPO=git@github.com:zalewskigrzegorz/dotfiles.git ./bootstrap.sh homelab
```

`bootstrap.sh` installs `chezmoi` if needed, writes the profile config, runs `chezmoi init`, then `chezmoi apply`.

## Packages

Package installation is driven by `~/.Brewfile`, rendered from `dot_Brewfile.tmpl`. The first apply installs Homebrew/Linuxbrew when missing, but `brew bundle` is opt-in while the app list is being reviewed:

```bash
brew bundle --global
# or
DOTFILES_RUN_BREW_BUNDLE=1 chezmoi apply
```

## Apply updates

```bash
git pull
sync
```

If `lazygit` has auto-migrated `~/.config/lazygit/config.yml`, chezmoi may ask whether to overwrite it. Either answer **yes** once, or run `chezmoi apply --force` to take the version from this repo.

### Homelab: secrets after apply

`sync` runs `chezmoi apply`, which runs `run_after_05-restore-private-files.sh` and restores private files from 1Password:

1. Install `op` (`brew install 1password-cli` or via `brew bundle` from the Linux Brewfile).
2. Reload the shell (`exec nu` or new SSH session) so `PATH` includes Linuxbrew.
3. Run `git pull`, then `sync`. If `op` has an account but no active session, `sync` starts `op signin` and uses that session for the restore.

If no 1Password account is configured, run `op account add` once. On a headless server, export `OP_SERVICE_ACCOUNT_TOKEN` before `sync`; if a TTY is available, `sync` can also prompt for that token.

Until `op` is on `PATH` and authenticated, `sync` will apply public dotfiles and skip only the private restore.

## Setapp

Set `setapp = true` in the profile config on a macOS workstation to include the Setapp cask.

Setapp manages its own apps after login. Track expected apps in `docs/setapp-apps.md` and check them with:

```bash
scripts/list-setapp-apps.sh
scripts/check-setapp-apps.sh
```

## Agent config (Claude Code)

Single-source-of-truth folders at repo root hold the agent config. `chezmoi apply` renders/syncs them into `~/.claude/*`.

| Folder | Lives in repo as | Pushed to | Rendered by |
| --- | --- | --- | --- |
| Skills | `agent-skills/<name>/SKILL.md` | `~/.claude/skills/` | `run_onchange_after_30-agent-skills-sync.sh.tmpl` (rsync) |
| Rules (global) | `agent-rules/<name>.md` (+ frontmatter) | `~/.claude/CLAUDE.md` (only `alwaysApply: true`) | `run_onchange_after_31-agent-rules-sync.sh.tmpl` |
| MCP servers (global) | `agent-mcp/mcp-servers.json.tmpl` | Claude user-scope via `claude mcp add` | `run_onchange_after_32-agent-mcp-sync.sh.tmpl` |

Project-scoped configs are not touched: `<repo>/CLAUDE.md`, `<repo>/.mcp.json` stay per-project.

Add or change shared content, then run `chezmoi apply`. For an ad-hoc skill resync without other chezmoi changes:

```bash
sync-agent-skills
```

See `docs/agents-sync.md` for details (adding a new skill/rule/MCP server, secrets via 1Password, troubleshooting).

## Reference

- Agent config (shared + per-agent): `docs/agents-sync.md`
- MCP client setup (Raycast/Claude): `docs/mcp-clients-setup.md`
- Dotfiles inventory: `docs/dotfiles-inventory.md`
