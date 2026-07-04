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

## Work identifiers (org / team / roster / Slack IDs)

The public repo never names the employer, team, coworkers, clients, or Slack IDs.
Those live in three private artifacts, all restored by `run_after_05` from the
1Password `Dotfiles` vault:

| 1Password item (document) | Restored to | Consumed by |
|---|---|---|
| `WORK_CONTEXT_MD` | `~/.local/state/dotfiles/secrets/work-context.md` | skills at runtime (daily-brief, g-pr-bump, …) — roster, team scope, Slack channel/subteam tables |
| `WORK_ENV` | `~/.local/state/dotfiles/secrets/work.env` | `bin/prs`, `bin/pr-watch`, `bin/pr-brief`, `bin/pr-watch-open`, g-* skills; loaded into the shell env by `dot_config/nushell/autoload/work-env.nu` (`WORK_GITHUB_ORG`, `WORK_MAIN_REPO`, `WORK_MONOREPO_DIR`, `WORK_TEAM_SLUG`, `WORK_TEAM_LABEL`) |
| `DOTFILES_WORK_DATA` | `<source-dir>/.chezmoidata/private-work.toml` (gitignored) | chezmoi templates: gh-dash config, mcp-servers, Stream Deck Slack buttons (`{{ index . "work" ... }}`) |
| `PRIVATE_AGENT_ASSETS_TAR` | `~/.local/state/dotfiles/secrets/private-agent-assets.tar` (auto-extracted) | private skills/rules overlay (`agent-skills/`, `agent-rules/` inside the tar) — layered into `~/.claude` + `~/.cursor` by sync scripts 30/31 after the public rsync |

Password-field items:

| 1Password item | Field | Used by |
|---|---|---|
| `OPENAPI_IDE_EXTENSION_KEY` | `password` | VS Code + Cursor `settings.json.tmpl` (`REDACTED_ORGOpenAPI.api.key`) |

Fresh-machine bootstrap note: the first `chezmoi apply` renders templates before
`run_after_05` restores `.chezmoidata/private-work.toml`, so work-templated files
render with empty defaults; the second `sync` fills them in.

## Private Gitleaks Rules

The tracked `.gitleaks.toml` contains only generic rules. Private identifier rules live outside the repo:

```text
~/.local/state/dotfiles/secrets/gitleaks-private.toml
```

The same content is backed by the `GITLEAKS_PRIVATE_CONFIG` item in the 1Password `Dotfiles` vault. `sync` restores it automatically. Run both public and private checks with:

```bash
bin/gitleaks-dotfiles --no-git --redact --log-level error
```

### Enforcement (tracked git hooks)

`scripts/git-hooks/pre-commit` and `pre-push` run gitleaks with BOTH configs;
`run_onchange_after_36-git-hooks.sh` wires them via `git config core.hooksPath
scripts/git-hooks`. A missing private config **blocks** commits and pushes
(escape hatch: `DOTFILES_SKIP_PRIVATE_GITLEAKS=1`). `bin/gitleaks-dotfiles`
likewise exits non-zero when the private config is missing.

## Stream Deck → Homey (macOS only)

The Stream Deck Office page hits the Homey Athom cloud API
(`https://<HOMEY_ID>.connect.athom.com`). Two secrets back it, restored by
`run_after_05` into `~/.config/streamdeck/homey-token` and
`~/.config/streamdeck/homey-id`:

| 1Password item (vault `Dotfiles`) | `password` field holds | Restored to |
|---|---|---|
| `HOMEY_TOKEN` | Athom cloud API bearer token | `~/.config/streamdeck/homey-token` |
| `HOMEY_ID` | Homey cloud ID (subdomain) | `~/.config/streamdeck/homey-id` |

Create both as **Password** items in the `Dotfiles` vault with the value in the
`password` field (`op://Dotfiles/HOMEY_TOKEN/password`). macOS-only — the lab has
no Stream Deck, so the "Skipping HOMEY_TOKEN…" notice during `chezmoi apply`
there is expected and harmless. The Homey **MCP** server
(`https://mcp.lab/homey/mcp`) is unrelated; it keeps its own credentials
server-side and does not use these.

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

## Zero-prompt op access (Service Account Token)

To eliminate Touch ID prompts on Mac and `op signin` failures over non-TTY SSH on the lab, drop a Service Account token at `~/.config/op/sa-token` (chmod 600) on each machine. Both `dot_config/nushell/env.nu.tmpl` and `dot_profile` auto-export it as `OP_SERVICE_ACCOUNT_TOKEN` when the file exists, so `op` runs headless everywhere.

### One-time setup per machine

1. **Create the token** (once, total — same token for every machine):
   - Go to <https://my.1password.com> → **Developer** → **Service Accounts** → **Create Service Account**.
   - Name: `Dotfiles sync` (or similar).
   - Vault access: **Dotfiles**, **Read items** only. Do NOT grant write — these tokens never need to mutate the vault.
   - Copy the `ops_xxx...` token. It's shown ONCE, save it immediately.

2. **Drop it on each machine**:

   ```bash
   mkdir -p ~/.config/op
   printf '%s' 'ops_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' > ~/.config/op/sa-token
   chmod 600 ~/.config/op/sa-token
   ```

3. **Tell chezmoi to use the service-account mode** (one-time, per machine). chezmoi's default `onepassword.mode = "account"` ignores the SA token AND throws `onepassword.mode is account, but OP_SERVICE_ACCOUNT_TOKEN is set` on first template render. Edit `~/.config/chezmoi/chezmoi.toml` (NOT in the dotfiles repo — it's the chezmoi-itself bootstrap config) and add near the top:

   ```toml
   [onepassword]
   mode = "service-account"
   ```

4. **Reload the shell** (`exec nu` on Mac, new SSH session on lab). Verify:

   ```bash
   echo "${OP_SERVICE_ACCOUNT_TOKEN:0:8}…"   # should print "ops_xxxx…"
   op whoami                                  # should not prompt
   ```

After this, `sync` / `chezmoi apply` / `lab-sync` all run without password prompts.

### File location is INTENTIONAL

`~/.config/op/sa-token` is **outside the dotfiles repo**. Do not run `chezmoi add` on it — the token would land in `dot_config/op/sa-token` in the git source and leak. The dotfiles config (`env.nu.tmpl` + `dot_profile`) only references the live path.

### Token rotation

Tokens rotate by deleting the old Service Account in 1Password.com (revokes immediately) and creating a new one. Drop the new value at `~/.config/op/sa-token` on each machine, reload the shell. No code change required.

### Why not store the SA token in 1Password itself?

Chicken-and-egg: `op` needs the SA token before it can read anything from 1Password. Storing the token in 1Password means we need a different `op` session to fetch it, which defeats the purpose. The token lives in a plain mode-600 file by design.
