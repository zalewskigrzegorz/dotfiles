# dotfiles

Personal dotfiles managed by [chezmoi](https://chezmoi.io). `chezmoi apply` must reproduce the full setup on a fresh machine (macOS workstation + Debian lab).

## Hard rules

1. **All settings live here.** Every plugin, MCP server, skill, hook, permission, keybinding, brew formula, and tool config must be mirrored into this repo. If something only exists in `~/` and not under `~/Code/dotfiles/`, it is invisible to `chezmoi apply` and will not survive a reinstall.
2. **Commit directly to `master`.** No feature branches, no PRs — this is a personal repo. Push when ready.
3. **Add via chezmoi, not manual copy.** Use `chezmoi add ~/<path>` so the source naming (`dot_*`, `private_*`, `executable_*`, `.tmpl`) is correct.
4. **Don't edit synced output.** When a source exists under `agent-skills/`, `agent-rules/`, `agent-mcp/`, `agent-plugins/`, or `dot_*`, edit the source — `chezmoi apply` overwrites the target.
5. **Claude skills go in `agent-skills/`, NOT `dot_claude/skills/`.** `run_onchange_after_30` does `rsync --delete agent-skills/ → ~/.claude/skills/` — anything in `~/.claude/skills/` that isn't in `agent-skills/` is wiped on every apply. If you run `chezmoi add ~/.claude/skills/<x>` you'll create `dot_claude/skills/<x>` that never reaches the target — always `cp -r ~/.claude/skills/<x> agent-skills/<x>` instead.

## Project structure

```
~/Code/dotfiles/
├── CLAUDE.md, README.md, LICENSE
├── .gitignore, .gitleaks.toml, .chezmoiignore
├── bootstrap.sh                    # one-shot machine bootstrap
├── dot_Brewfile.tmpl               # brew bundle source (templated by profile)
├── nushell-mcp.json.tmpl           # MCP servers for the nushell mcp integration
├── dot_claude/                     # → ~/.claude (settings, hooks, output-styles, skills/, statusline)
├── dot_config/                     # → ~/.config (nushell, tmux, nvim, ghostty, sketchybar, ...)
├── dot_cursor/                     # → ~/.cursor
├── private_dot_ssh/                # → ~/.ssh (mode 0600, templated)
├── agent-plugins/plugins.json.tmpl # Claude Code plugin install list
├── agent-mcp/mcp-servers.json.tmpl # Claude Code MCP server list
├── agent-rules/                    # synced into ~/.claude (and ~/.cursor) as rule docs
├── agent-skills/                   # synced into ~/.claude/skills + ~/.cursor/skills
├── bin/                            # PATH-exposed scripts (sync, gitleaks-dotfiles, ...)
├── scripts/                        # repo maintenance scripts (not on PATH)
├── docs/                           # operational notes (inventory, secrets, setapp, mcp setup)
├── brew/                           # brew-related helpers
├── legacy/                         # archived configs (do not edit)
├── private/                        # gitignored secrets staging area
└── run_*                           # chezmoi lifecycle hooks (see Setup order)
```

## Source naming

- `dot_*` → `~/.* ` (e.g. `dot_claude/` → `~/.claude/`, `dot_config/` → `~/.config/`)
- `*.tmpl` → rendered by chezmoi (use `chezmoi execute-template < file.tmpl` to preview)
- `private_*` → file mode 0600
- `executable_*` → file mode 0755
- `run_once_*` / `run_onchange_*` / `run_after_*` → chezmoi lifecycle hooks (see below)

## Setup order (`chezmoi apply` runs these in numeric order)

| Stage | Script | What it does |
|---|---|---|
| 00 | `run_once_before_00-install-homebrew.sh.tmpl` | Install Homebrew (Mac + Linux) |
| 05 | `run_after_05-restore-private-files.sh.tmpl` | Restore secrets from `private/` |
| 10 | `run_onchange_after_10-brew-bundle.sh.tmpl` | `brew bundle` against rendered Brewfile |
| 15 | `run_onchange_after_15-macos-nushell-application-support.sh.tmpl` | macOS-only nushell support |
| 20 | `run_onchange_after_20-macos-xdg-launchagent.sh.tmpl` | macOS XDG launch agent |
| 25 | `run_once_after_25-install-claude.sh.tmpl` | Install Claude Code CLI |
| 30 | `run_onchange_after_30-agent-skills-sync.sh.tmpl` | rsync `agent-skills/` → `~/.claude/skills`, `~/.cursor/skills` |
| 31 | `run_onchange_after_31-agent-rules-sync.sh.tmpl` | rsync `agent-rules/` |
| 32 | `run_onchange_after_32-agent-mcp-sync.sh.tmpl` | apply `agent-mcp/mcp-servers.json.tmpl` |
| 33 | `run_onchange_after_33-claude-plugins-sync.sh.tmpl` | apply `agent-plugins/plugins.json.tmpl` |
| 35 | `run_after_35-raycast-scripts-compat.sh.tmpl` | Raycast compatibility shim |
| 45 | `run_once_after_45-install-tmux-plugins.sh` | TPM + tmux plugins |

Bootstrap from scratch: `./bootstrap.sh` (installs chezmoi + runs first apply).

## Common commands

```bash
chezmoi diff                       # preview pending changes (run before commit)
chezmoi apply                      # apply repo → live (idempotent)
chezmoi update                     # git pull + apply (use on lab)
chezmoi add ~/<path>               # track a new file
chezmoi re-add ~/<path>            # update tracked file from live
chezmoi execute-template < x.tmpl  # render a template to see output
bin/sync                           # wrapper: ensures PATH then `chezmoi apply`
bin/gitleaks-dotfiles              # scan repo for leaked secrets
```

For drift audits and add-app flows use the **`dotfiles-sync` skill** (`agent-skills/dotfiles-sync/SKILL.md`).

## Claude-specific

Global Claude config lives in `dot_claude/` → `~/.claude/`:

- `settings.json.tmpl` — main settings (templated for secrets)
- `keybindings.json` — key bindings
- `hooks/` — SessionStart, Stop, etc.
- `output-styles/` — custom response styles
- `skills/` — populated by `30-agent-skills-sync`; **edit `agent-skills/` instead**
- `executable_statusline.sh` — statusline script

Plugins / MCP / skills sources of truth:

- Claude plugins → `agent-plugins/plugins.json.tmpl`
- Claude MCP servers → `agent-mcp/mcp-servers.json.tmpl` (also `nushell-mcp.json.tmpl` for nushell integration)
- Claude / Cursor skills → `agent-skills/<skill-name>/SKILL.md`
- Claude / Cursor rules → `agent-rules/`

Anything installed via `/plugin install`, `claude mcp add`, or `~/.claude/skills/<new>` on a machine **must** be reflected in the matching source above before the next `chezmoi apply`.

## Secrets & private data

- `private/` — gitignored staging area, restored to `~/` by `run_after_05`
- `private_dot_ssh/` → `~/.ssh` at mode 0600 (templated)
- `.gitleaks.toml` — secret scanner config; run `bin/gitleaks-dotfiles` before pushing
- Templated secrets in `*.tmpl` files use chezmoi's secret functions (1Password on Mac, see `docs/secrets.md`)
- `1Password CLI` on Linux is **not** in homebrew — install via apt (see Linux block in `dot_Brewfile.tmpl`)

## Multiplexer — herdr (Mac)

- **`hd` / `herdr` is the launcher** (`dot_config/nushell/autoload/herdr.nu` → `hd`, `hd-restart`, `hd-stop`). Prefix = `ctrl+space`. The priority-sorted **agent sidebar** (blocked-first) is the core — it replaces the old `claude-agent-presence` stack and the window-wrappers. Worktrees via the herdr-native `work` CLI (`new`/`ls`/`switch`/`rm`/`pr`). Nav: `prefix+w` workspace picker · `prefix+g` goto · `prefix+a` agent-cycle · `prefix+0` jump-to-waiting-agent · `prefix+h/j/k/l` panes. Config: `dot_config/herdr/config.toml`. Full reference: `docs/herdr.md`.
- **tmux kept as a cold backup only (pre-herdr).** `dot_config/tmux/tmux.conf` (with `tmux-resurrect`/`tmux-continuum` and `zz-tmux-window-wrappers.nu`), `brew "tmux"`, and TPM stay in place but are NOT the active multiplexer. Revert = `git -C ~/Code/dotfiles checkout pre-herdr` (tag `pre-herdr` / branch `pre-herdr-backup`).

## Shell history (nushell)

- **`Ctrl+R` = fzf** over the nushell sqlite history (`dot_config/nushell/autoload/fzf-history.nu`). `Alt+T` = Television smart-autocomplete (`tv.nu`). TV's `nu-history` channel is **not** wired to Ctrl+R — its filter quality is too weak.
- **Do not propose Atuin** until upstream nushell issues close: [atuinsh/atuin#2900](https://github.com/atuinsh/atuin/issues/2900) (executehostcommand pastes literal text) + [#2820](https://github.com/atuinsh/atuin/issues/2820) (nu integration broken). Both still open as of 2026-05-16. Re-verify with `gh issue view` before recommending.

## Lab (`minis`, Debian) — connect & cold-start

> **herdr DEFERRED on lab** — the lab still runs tmux until herdr lands there (`default_shell` in `config.toml` is the Mac nu path, needs per-OS templatizing first). The nested-tmux workflow below is lab-current, NOT Mac-current; on the Mac use herdr (`hd`).

- SSH alias: `ssh lab` (chezmoi-templated `~/.ssh/config`); fallback `ssh lab-via-ip` (192.168.50.10).
- **One-time terminfo install per remote** so tmux/nvim accept `xterm-ghostty`:
  ```
  infocmp -x xterm-ghostty | ssh <host> -- tic -x -
  ```
- Lab login shell is `bash`, not nu. Either run `nu` after login or `chsh -s $(which nu)` (after adding nu to `/etc/shells`).
- **Pulling new dotfiles on lab from bash:** `chezmoi update` (runs `git pull` in `~/.local/share/chezmoi` + `chezmoi apply`). `~/Code/dotfiles` on lab is NOT a git checkout.
- Accepted workflow: `tn` on mac → SSH from inside that tmux window → `nu` + `tn`/`ta` on lab. Two status bars (mac-tmux + lab-tmux nested), prefix is `Space`, send to inner tmux via `Space Space` (`bind-key ' ' send-prefix`).

## Pointers

- `docs/dotfiles-inventory.md` — full inventory of what's tracked
- `docs/agents-sync.md` — agent-* sync internals
- `docs/mcp-clients-setup.md` — MCP setup per client
- `docs/secrets.md` — secret management workflow
- `docs/setapp-apps.md` — Setapp app handling
- `docs/streamdeck.md` — Stream Deck + layout + Homey office control
- `README.md` — public-facing intro (keep CLAUDE.md as the operational source)
