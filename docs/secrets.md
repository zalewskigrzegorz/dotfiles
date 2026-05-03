# Secrets

Do not commit work identifiers, team names, tokens, project updates, or private helper scripts to this repository.

Local-only files live outside the repo under:

```text
~/.local/state/dotfiles/secrets/
```

Current local-only files moved there:

- `project-update.md`
- `statuses/`

## Nushell Private Env

`~/.config/nushell/autoload/private.nu` is intentionally ignored. It is the right place for local environment variables and values fetched from a secret manager.

Use the 1Password vault `Dotfiles` for local values. The item title should match the environment variable name, and the secret value should be stored in that item's `password` field.

The tracked `dot_config/nushell/autoload/private.nu.tmpl` stays generic. The private variable list lives in ignored local chezmoi data:

```toml
# .chezmoidata/private-env.toml
onePasswordVault = "Dotfiles"
privateEnvVars = ["EXAMPLE_VARIABLE"]
```

`sync` restores the private weekly script from the `WEEKLY_PROJECT_UPDATE_SCRIPT` document in the 1Password `Dotfiles` vault.

Run it with:

```bash
bin/weekly-project-update --since YYYY-MM-DD
```

## Private Gitleaks Rules

The tracked `.gitleaks.toml` contains only generic rules. Private identifier rules live outside the repo:

```text
~/.local/state/dotfiles/secrets/gitleaks-private.toml
```

The same content is backed by the `GITLEAKS_PRIVATE_CONFIG` item in the 1Password `Dotfiles` vault. `sync` restores it automatically. Run both public and private checks with:

```bash
bin/gitleaks-dotfiles --no-git --redact --log-level error
```

## Sync Flow

On any machine with the repo:

```bash
git pull
sync
```

The `sync` command runs `chezmoi apply`. During apply, `run_after_05-restore-private-files.sh` restores local private runtime files into `~/.local/state/dotfiles/secrets/`. Generated status output is not synced; `statuses/` is created locally when needed.

If `op` has a configured account but no active session, `sync` starts `op signin` and uses the resulting session for this restore. If no account is configured, run `op account add` once. For headless servers, export `OP_SERVICE_ACCOUNT_TOKEN` before `sync`; with an interactive TTY, `sync` can prompt for that token.

### Linux / homelab

1. Install the CLI (Linuxbrew: `brew install 1password-cli`, or it is listed in `dot_Brewfile.tmpl` for Linux when you run `brew bundle`).
2. **Reload the shell** after install (`exec nu`, new SSH session, or open a new terminal) so `PATH` includes Linuxbrew before you run `sync`.
3. Run `git pull`, then `sync`.

Do **not** use `$(op signin)` in Nushell; it prints bash exports and does not update Nushell's environment. `sync` handles `op signin` inside the bash restore script, so the session only needs to live long enough to restore private files.

For headless servers, prefer a **1Password service account token** (`OP_SERVICE_ACCOUNT_TOKEN` in the environment for `op` and for `sync`) instead of interactive sign-in.

If `sync` still prints `Skipping private file restore`, run `command -v op` in the same shell; it must print a path. The restore script also prepends common Linuxbrew paths, but a stale session before `brew install` may not see `op` until you restart the shell.
