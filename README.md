# Dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/) and bootstrapped with Homebrew/Linuxbrew.

## Profiles

- `workstation` - macOS desktop/laptop with GUI apps, casks, Aerospace, SketchyBar, Cursor, Zed and Claude config.
- `homelab` - headless Debian/Ubuntu with CLI and shell config only. No casks, GUI apps, fonts, window manager or status bar tooling.

The active profile is stored in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
profile = "homelab"
setapp = false
```

Set `setapp = true` on a macOS workstation to include the Setapp cask.

Setapp manages its own apps after login. Track expected apps in `docs/setapp-apps.md` and check them with:

```bash
scripts/list-setapp-apps.sh
scripts/check-setapp-apps.sh
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

## Apply Updates

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

### tmux: window icons / names missing

Tab labels with icons come from TPM plugin `tmux-nerd-font-window-name` plus `~/.config/tmux/tmux-nerd-font-window-name.yml`. After a fresh machine or chezmoi migration:

1. Run `chezmoi apply` once so `run_once_after_45-install-tmux-plugins.sh` can clone TPM and install plugins (or inside tmux press **prefix + capital I** to install TPM plugins manually).
2. Restart tmux (or `tmux source-file ~/.config/tmux/tmux.conf`).
3. Your terminal profile must use a **Nerd Font** (otherwise icons render as empty boxes or disappear).

Package installation is driven by `~/.Brewfile`, rendered from `dot_Brewfile.tmpl`. The first apply installs Homebrew/Linuxbrew when missing, but `brew bundle` is opt-in while the app list is being reviewed:

```bash
brew bundle --global
# or
DOTFILES_RUN_BREW_BUNDLE=1 chezmoi apply
```

## Stow Migration

This repo used to be managed with GNU Stow. Before the first `chezmoi apply` on an existing host, remove legacy symlinks that point back into this repo:

```bash
legacy/migrate-stow-links-to-chezmoi.sh
legacy/migrate-stow-links-to-chezmoi.sh --apply
```

The script removes only symlinks whose targets are inside the current dotfiles checkout. It does not touch real files or directories.

## Reference

- Brew bundle reference: `docs/brew-snapshot-20260503.md`
- Stow link inventory: `docs/stow-links-before-chezmoi.md`
- Dotfiles inventory: `docs/dotfiles-inventory.md`
- Legacy Stow scripts: `legacy/`
