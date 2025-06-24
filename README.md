# Dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/) and automated with [Nushell](https://www.nushell.sh/) scripts.

## Prerequisites
- `stow`, `nushell`, `fzf`, `gitleaks` (install via homebrew)

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

## Security
Pre-commit hook with gitleaks prevents committing secrets. Sensitive configs (raycast, ssh, etc.) are automatically added to `.gitignore`.
