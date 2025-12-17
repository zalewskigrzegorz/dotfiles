# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and automated with [Nushell](https://www.nushell.sh/) scripts.

## Prerequisites

- `stow`, `nushell`, `fzf`, `gitleaks` (install via homebrew)

## Configuration

### MCP Server Configuration

The `nushell-mcp.json` file uses `~` for home directory paths. If your MCP client doesn't support tilde expansion, you'll need to replace `~` with your actual home directory path (e.g., `/Users/yourusername`) after installation.

## Usage

### Import configs from ~/.config

```bash
nu import-config.nu
```

Interactive script that lets you select configs with fzf, copies them to the repo, and handles sensitive configs automatically.

### Apply symlinks

```bash
nu apply-symlinks.nu
```

Shows status of all configs, creates backups, and runs `stow .` to create symlinks.

### Manual

```bash
stow .
```

## Scripts

**`import-config.nu`** - Finds configs in `~/.config` that aren't already managed, lets you multi-select with fzf, copies them to `.config/`, and optionally runs the symlink script.

**`apply-symlinks.nu`** - Shows which configs are linked (🔗), new (🆕), or need backup (📦). Creates timestamped backups in `backups/` before running stow.

**`fix-macos-path.nu`** - Generates a macOS LaunchAgent plist file to set XDG environment variables system-wide. This fixes GUI apps that don't respect XDG config directories on macOS.

## macOS XDG Environment Fix

Many GUI apps on macOS don't respect XDG config directories and save configs in `~/Library/Application Support`. To fix this system-wide:

```bash
# Generate and install the LaunchAgent
nu fix-macos-path.nu

# Activate it (will run on every login)
launchctl load ~/Library/LaunchAgents/me.greg.environment.plist
```

This sets the following environment variables for all GUI applications:

- `XDG_CONFIG_HOME` → `~/.config`
- `XDG_CACHE_HOME` → `~/.cache`
- `XDG_DATA_HOME` → `~/.local/share`
- `XDG_STATE_HOME` → `~/.local/state`
- `XDG_RUNTIME_DIR` → `~/.local/run`
- `XDG_BIN_HOME` → `~/.local/bin`

## Security

Pre-commit hook with gitleaks prevents committing secrets. Sensitive configs (raycast, ssh, etc.) are automatically added to `.gitignore`.

### TODO

- [x] fuzzy search in hidden files in vim
- [x] file search in hidden files in vim
- [ ] configure sketchybar
- [ ] change tmux navigator vim plugin to work with aerospace detection
- [ ] add a script to quickly add new line to nav

