# Dotfiles Inventory

This inventory was created during the Stow to chezmoi migration.

## Portable CLI

These are applied on macOS workstation and Debian homelab:

- `dot_config/atuin`
- `dot_config/btop`
- `dot_config/carapace`
- `dot_config/gh`
- `dot_config/lazydocker`
- `dot_config/lazygit`
- `dot_config/lynx`
- `dot_config/navi`
- `dot_config/nushell`
- `dot_config/nvim`
- `dot_config/starship`
- `dot_config/superfile`
- `dot_config/television`
- `dot_config/tmux`
- `dot_config/zellij`
- `bin`

## Homebrew

- **Canonical bundle:** `dot_Brewfile.tmpl` (chezmoi).
- **Full snapshot (extra formulae, casks with tap prefixes, VS Code pins):** `brew/Brewfile.current`.
- **Human-readable lists:** `docs/brew-snapshot-20260503.md`.

## GitHub CLI extensions

Installed by `run_onchange_after_35-gh-extensions.sh` (both profiles). The
`EXTENSIONS` array in that script is the source of truth — the extensions
themselves live in `~/.local/share/gh/extensions`, which chezmoi does not track,
so anything installed by hand and not listed here dies on the next machine.

| Extension | Repo | Why it's here |
|---|---|---|
| `gh stack` | `github/gh-stack` | native stacked PRs; backs the `work pr` stack sub-picker |
| `gh dash` | `dlvhdr/gh-dash` | PR/issue dashboard TUI — config in `dot_config/private_gh-dash`, wrapper `dash` |
| `gh combine-prs` | `rnorth/gh-combine-prs` | combine matching PRs (dependabot batches) into one |
| `gh contribute` | `vilmibm/gh-contribute` | suggest an issue to work on in a repo |
| `gh copilot` | `github/gh-copilot` | `gh copilot suggest` / `explain` |
| `gh standup` | `sgoedecke/gh-standup` | GitHub-activity standup report |
| `gh tidy` | `HaywardMorihara/gh-tidy` | pull default branch, `git gc`, prune merged local branches |

The script skips already-installed extensions and no-ops when `gh` is missing or
unauthenticated. Upgrades are **not** automatic: `gh extension upgrade --all`.

## Local code-indexing tools

Installed as **uv tools** (→ `~/.local/bin`) by
`run_onchange_after_26-code-index-tools.sh.tmpl`. Both run 100% locally — no
cloud embedding provider, no external vector DB, no API keys.

| Tool | uv package | Role | Wired via |
|---|---|---|---|
| Serena | `serena-agent` | LSP-based semantic nav MCP; auto-downloads its own TS/JS language server | user-scope MCP in `agent-mcp/mcp-servers.json.tmpl` |

- **CocoIndex (`ccc`) removed 2026-08-05.** Per-session `ccc mcp` loaded a local
  embedding model into its own Python fleet and re-indexed each worktree; with
  ~7 concurrent Claude sessions the wake-from-sleep herd (8 serena + 22 cocoindex
  procs) starved WindowServer and froze the UI. Dropped from the plugin list
  (`agent-plugins/plugins.json.tmpl`), the install script, and the rules. Serena
  is the only local code-intelligence server now.

## Cursor

- **`dot_cursor/` → `~/.cursor/`** (chezmoi): settings, hooks, **`rules/`** (global assistant rules), **`skills/`**. On **`homelab`** profile, `.cursor/**` targets are skipped (see `.chezmoiignore`) — no Cursor sync on headless hosts.
- **`.cursor/rules/`** at repo root (not under `dot_cursor/`): workspace-only rules when **this dotfiles repo** is the Cursor project (e.g. `dotfiles-architecture.mdc`). Keeps repo-specific AI instructions out of `~/.cursor/rules`.

## macOS Workstation Only

These are ignored when `profile = "homelab"`:

- `dot_config/aerospace`
- `dot_config/borders`
- `dot_config/cursor`
- `dot_config/flipperdevices.com`
- `dot_config/ghostty`
- `dot_config/sketchybar`
- `dot_config/spotify-player`
- `dot_config/svim`
- `dot_config/zed`
- `dot_cursor`
- `dot_claude`
- `nushell-mcp.json.tmpl`
- `bin/aerospace-flip-window`
- `bin/sketchybar-watcher`
- `bin/sketchybar-watcher-bin`

## Generated Or Removed From Management

These were removed from git tracking during the migration:

- `.claude/hooks/peon-ping/.last_update_check`
- `.claude/hooks/peon-ping/.relay.pid`
- `.claude/hooks/peon-ping/.sound.pid`
- `.claude/hooks/peon-ping/.state.json`
- `.claude/hooks/peon-ping/.update_available`
- `.config/cursor/chats/**/store.db`
- `.config/nushell/env.nu.bak-work-migration`
- `.config/nushell/vendor/autoload/starship.nu`
- `.config/zed/.tmp*`
- `.config/zed/embeddings/**`
- `.config/zed/prompts/**`

## Legacy

These are no longer part of the active bootstrap flow:

- `legacy/apply-symlinks.nu`
- `legacy/import-config.nu`
- `legacy/fix-macos-path.nu`
- `legacy/setup.nu`
- `legacy/migrate-stow-links-to-chezmoi.sh`
- `.stowrc` removed
