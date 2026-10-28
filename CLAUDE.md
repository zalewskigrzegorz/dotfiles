# dotfiles

Personal dotfiles managed by [chezmoi](https://chezmoi.io). `chezmoi apply` must reproduce the full setup on a fresh machine (macOS workstation + Debian lab).

## Hard rules

1. **All settings live here.** Every plugin, MCP server, skill, hook, permission, keybinding, brew formula, and tool config must be mirrored into this repo. If something only exists in `~/` and not under `~/Code/dotfiles/`, it is invisible to `chezmoi apply` and will not survive a reinstall.
2. **Commit directly to `master`.** No feature branches, no PRs — this is a personal repo. Finished work is committed and pushed through the end-of-task popup (`agent-rules/commit-message-rules.md`).
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
├── dot_config/                     # → ~/.config (nushell, tuios, nvim, ghostty, sketchybar, ...)
├── private_dot_ssh/                # → ~/.ssh (mode 0600, templated)
├── agent-plugins/plugins.json.tmpl # Claude Code plugin install list
├── agent-mcp/mcp-servers.json.tmpl # Claude Code MCP server list
├── agent-rules/                    # rendered into ~/.claude/CLAUDE.md
├── agent-skills/                   # synced into ~/.claude/skills
├── bin/                            # PATH-exposed scripts (sync, gitleaks-dotfiles, ...)
├── scriptc/                        # TypeScript compiled to native binaries in bin/ (stage 29)
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
| 13 | `run_onchange_after_13-macos-sudo-touchid.sh.tmpl` | Touch ID for `sudo` via `/etc/pam.d/sudo_local` + `pam_reattach`, macOS only |
| 14 | `run_onchange_after_14-macos-defaults.sh.tmpl` | macOS defaults (Dock, hidden menu bar, Finder) + `brew services start sketchybar`, macOS only |
| 15 | `run_onchange_after_15-macos-nushell-application-support.sh.tmpl` | macOS-only nushell support |
| 16 | `run_onchange_after_16-sketchybar-deps.sh.tmpl` | SbarLua + sketchybar-app-font (sketchybar's Lua config is empty without them), macOS only |
| 20 | `run_onchange_after_20-macos-xdg-launchagent.sh.tmpl` | macOS XDG launch agent |
| 25 | `run_once_after_25-install-claude.sh.tmpl` | Install Claude Code CLI |
| 27 | `run_onchange_after_27-browserskill.sh.tmpl` | Install the `bsk` CLI (BrowserSkill), macOS only |
| 28 | `run_onchange_after_28-bin-exec-bits.sh.tmpl` | rsync `bin/` → `~/bin` (keeps the exec bit; `bin/**` is chezmoi-ignored) |
| 29 | `run_onchange_after_29-scriptc-build.sh.tmpl` | compile `scriptc/*.ts` → native binaries in `bin/` + `~/bin` |
| 30 | `run_onchange_after_30-agent-skills-sync.sh.tmpl` | rsync `agent-skills/` → `~/.claude/skills` |
| 31 | `run_onchange_after_31-agent-rules-sync.sh.tmpl` | rsync `agent-rules/` |
| 32 | `run_onchange_after_32-agent-mcp-sync.sh.tmpl` | apply `agent-mcp/mcp-servers.json.tmpl` |
| 33 | `run_onchange_after_33-claude-plugins-sync.sh.tmpl` | apply `agent-plugins/plugins.json.tmpl` |
| 34 | `run_after_34-collie.sh` | macOS only: install Collie standalone, write `~/.config/herdr/plugins/config/herdr.collie/.env` (Collie reads it before `~/.config/collie`) (`COLLIE_MUX=tuios`), `collie start` |
| 35 | `run_after_35-raycast-scripts-compat.sh.tmpl` | Raycast compatibility shim |
| 35 | `run_onchange_after_35-gh-extensions.sh` | install `gh` CLI extensions (gh-dash, gh-stack, …) |
| 36 | `run_onchange_after_36-git-hooks.sh.tmpl` | wire tracked git hooks (`core.hooksPath` → gitleaks pre-commit/pre-push) |

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

## Drift audit & adding apps

Run **`bin/audit-drift`** first — it prints a classified view of `chezmoi diff` as `PATH | KIND | SUGGESTED_ACTION` without loading any file content:

- `FILE_DRIFT` — plain file, `chezmoi re-add` captures it
- `TEMPLATE_DRIFT` — source is `.tmpl`; `re-add` may no-op even when live differs, because the template still renders to live. Needs the manual rewrite below.
- `BINARY_DRIFT` — as FILE_DRIFT, but watch the exec bit (`re-add` can drop it if the source lacks the `executable_` prefix)
- `FAKE_SCRIPT` — a `run_*` script that always shows in `chezmoi diff` because it executes every apply. Not real drift.

`bin/audit-drift` is a **compiled binary, gitignored** — the source is `scriptc/audit-drift.ts` and stage 29 builds it (see "Native helpers" below). Edit the `.ts`, never the binary.

**Fake-drift traps fixed 2026-08-20** (details: `docs/dotfiles-inventory.md` → "Fake drift"): keep `umask = 0o022` pinned in `chezmoi.toml` + `bootstrap.sh`, and never rename `bin/*` to `executable_*` (stage 28 rsyncs them).

A healthy `chezmoi status` is now ~2 rows, both `R` script rows. Anything more is real.

When `bin/audit-drift` isn't enough, compare each live source against the repo:

| Check | Live | Repo |
|---|---|---|
| brew formulae / casks / taps | `brew leaves`, `brew list --cask`, `brew tap` | `dot_Brewfile.tmpl` |
| Claude plugins | `claude plugin list` | `agent-plugins/plugins.json.tmpl` |
| Claude MCP servers | `claude mcp list` | `agent-mcp/mcp-servers.json.tmpl`, `nushell-mcp.json.tmpl` |
| Claude skills | `ls ~/.claude/skills/` | `ls agent-skills/` |
| Claude hooks / output-styles | `ls ~/.claude/{hooks,output-styles}/` | `dot_claude/{hooks,output-styles}/` |
| `gh` CLI extensions | `gh extension list` | `run_onchange_after_35-gh-extensions.sh` (`EXTENSIONS` array) |

Classify each row `LIVE_ONLY` (add to repo), `REPO_ONLY` (`chezmoi apply`, or an intentional removal), or `MODIFIED` (`chezmoi re-add` for live→repo, `chezmoi apply` for repo→live). Apply in order: edit `.tmpl` files, then `re-add`, then `bin/sync` last. Verify with an empty `chezmoi diff`.

The Brewfile is templated, so a raw grep misses entries behind `{{ if }}` — render first with `chezmoi execute-template < dot_Brewfile.tmpl`. Check `.chezmoiignore` before flagging "missing in repo".

**Adding one app:**

1. brew formula/cask (`brew info <X>` confirms) → append to the matching section of `dot_Brewfile.tmpl`, alphabetical within section. If it has config, `chezmoi add ~/.config/<X>`.
2. Claude plugin → `agent-plugins/plugins.json.tmpl`
3. MCP server → `agent-mcp/mcp-servers.json.tmpl` (or `nushell-mcp.json.tmpl`)
4. Claude skill → `cp -r ~/.claude/skills/<X> agent-skills/<X>` (never `chezmoi add` — see hard rule 5)
5. `gh` extension → append `owner/repo` to the `EXTENSIONS` array in `run_onchange_after_35-gh-extensions.sh` (never `gh extension install` alone — extensions live in untracked `~/.local/share/gh/`)
6. Any other dotfile → `chezmoi add <path>`, then check the source name got the right prefix

Finish with `chezmoi diff` to confirm the change was captured, then close the task with the commit + push popup.

**Template-aware re-sync (live → `.tmpl`).** When the source is a `.tmpl`, live drifted, and live is the truth: `chezmoi re-add` is a no-op, so rewrite by hand. Inventory every `{{ ... }}` token in the existing template first — `.chezmoi.*`, `if eq .chezmoi.os` branches, `includeTemplate`, secret functions — copy live in verbatim, then put each token back. Verify byte-identity with `bin/render-and-diff <source.tmpl>` (exit 0 = match, 1 = diff, 2 = bad invocation). Mentally render the *other* OS branch before committing; nothing checks it automatically. Decide once whether live or the template is canonical and stop oscillating.

Live drift in `~/.claude/skills/<name>/` is **overwritten** on the next apply unless persisted back into `agent-skills/`.

## Native helpers — `scriptc/`

Notes, footguns and porting rules: `scriptc/CLAUDE.md` (loads when you touch `scriptc/`). Read it before editing any `scriptc/*.ts`.

## Claude-specific

**Testing a `pre-tool-use/*` hook.** Feed it fixture JSON on stdin with guards on (no YOLO marker, `permission_mode: default`) and read `hookSpecificOutput.permissionDecision`; a table of `command → expect allow|ask|deny` cases, run against the working copy **and** against `git show HEAD:<hook>` in a scratch dir, separates a regression from old behaviour in one pass and catches inconsistencies (2026-09-25: commit asked while push passed). Only the cases whose result changed need reading. The `/dev/null;` false positive (fixed 2026-09-29) had exactly this shape.

**ponytail band.** Toggled with `/ponytail band [off]`; its state is `~/.claude/.ponytail-band`, tracked as `dot_claude/dot_ponytail-band` (69a88ca). Its buttons need the mouse, which does not exist with the alt screen off. Never patch `register.tsx` (`agent-rules/plugin-own-switch-not-patch.md`). A running session keeps the old band until `/exit` + `claude --continue`.

Global Claude config lives in `dot_claude/` → `~/.claude/`:

- `modify_settings.json.tmpl` — a chezmoi `modify_` script that merges the managed keys into the live `~/.claude/settings.json`; the settings themselves live in `.chezmoitemplates/claude-settings.json` — edit that, there is no `dot_claude/settings.json.tmpl`
- `keybindings.json` — key bindings
- `hooks/` — SessionStart, Stop, etc.
- `output-styles/` — custom response styles
- `skills/` — populated by `30-agent-skills-sync`; **edit `agent-skills/` instead**
- `executable_statusline.sh` — statusline script

Plugins / MCP / skills sources of truth:

- Claude plugins → `agent-plugins/plugins.json.tmpl`
- Claude MCP servers → `agent-mcp/mcp-servers.json.tmpl` (also `nushell-mcp.json.tmpl` for nushell integration)
- Claude skills → `agent-skills/<skill-name>/SKILL.md`
- Claude rules → `agent-rules/`

Anything installed via `/plugin install`, `claude mcp add`, or `~/.claude/skills/<new>` on a machine **must** be reflected in the matching source above before the next `chezmoi apply`.

#### Local code-indexing tools (Serena)

100%-local semantic code nav for Claude Code — no cloud, no API keys.
Installed as a **uv tool** (→ `~/.local/bin`) by
`run_onchange_after_26-code-index-tools.sh.tmpl`.

- **Serena** (`oraios/serena`) — LSP-based semantic nav. User-scope MCP in
  `agent-mcp/mcp-servers.json.tmpl` (`serena start-mcp-server --context claude-code
  --project-from-cwd`). Auto-downloads its own TS/JS language server on first use
  — no `typescript-language-server`/`typescript` needed on PATH.
- **CocoIndex (`ccc`) REMOVED 2026-08-05.** Each session's `ccc mcp` loaded a
  local embedding model into its own Python fleet and re-indexed every worktree
  separately; with ~7 concurrent sessions the wake-from-sleep thundering herd
  (8 serena + 22 cocoindex procs) starved WindowServer and froze the UI. Net
  cost > benefit. Gone from the plugin list, install script, and rules. Don't
  reinstall it or add `ccc` anywhere.

#### Browser automation — three stacks (Mac)

When to use which: `agent-rules/browserskill-agent-window.md`. Sources: `agent-browser` → `agent-skills/agent-browser/`; `browsentic` → stage 12 npm globals + `agent-mcp/mcp-servers.json.tmpl` + `agent-skills/browsentic/`; `bsk` → stage 27 + `agent-skills/bsk/`. Install, `bsk doctor`, skill refresh, retired `claude-in-chrome`: `docs/browser-automation.md`.

### Skille z skills.sh (ephemeral)

Jednorazowa wiedza domenowa: **`skill-scout`** → `npx skills use <owner/repo@skill>` (nic nie instaluje; `npx skills add` blokuje guard). Na stałe: `cp -r <temp-dir>/<skill> agent-skills/<skill>` + commit.

## Secrets & private data

- `private/` — gitignored staging area, restored to `~/` by `run_after_05`
- `private_dot_ssh/` → `~/.ssh` at mode 0600 (templated)
- **Work identifiers (employer, team, roster, Slack IDs, client names) NEVER go in this repo** — it's public. They live in `~/.local/state/dotfiles/secrets/{work-context.md,work.env}` + `.chezmoidata/private-work.toml` (gitignored), all restored from 1Password (see `docs/secrets.md` → "Work identifiers"). Skills reference *work-context*; scripts read `WORK_*` env vars; templates use `{{ index . "work" ... }}`.
- **A local edit to a restored secret file dies on the next `bin/sync`.** `run_after_05` runs on every apply and does `op document get --force`, so `work-context.md`, `work.env` and the rest come back from the vault. Push the edit first — `op document edit <ITEM> <file> --vault Dotfiles` (item names in `docs/secrets.md`) — then `op document get` it to a scratch file and `cmp` it against the local file, and only then sync.
- Private skills/rules (client/product-specific) go in the `PRIVATE_AGENT_ASSETS_TAR` 1Password overlay, not `agent-skills/`/`agent-rules/`.
- `.gitleaks.toml` — public scanner rules; private identifier rules in `~/.local/state/dotfiles/secrets/gitleaks-private.toml`. Enforced by **tracked hooks** `scripts/git-hooks/{pre-commit,pre-push}` (wired via `core.hooksPath` by `run_onchange_after_36`); both block when the private config is missing. Manual full scan: `bin/gitleaks-dotfiles`.
- Templated secrets in `*.tmpl` files use chezmoi's secret functions (1Password on Mac, see `docs/secrets.md`)
- `1Password CLI` on Linux is **not** in homebrew — install via apt (see Linux block in `dot_Brewfile.tmpl`)

## Path-scoped notes — `.claude/rules/`

sketchybar, nushell autoload and workctl / gh-dash gotchas load on demand from `.claude/rules/*.md` (`paths:` frontmatter) when a matching file is read or edited. Put new file-specific gotchas there, not here: instruction files share a 150k-char budget.

## Multiplexer — tuios (Mac)

- **`tuios` is the launcher** (helpers in `dot_config/nushell/autoload/tuios.nu`: `os-restart`, `os-stop`, `os-mrglaszki`). Vocabulary: a tuios **session** = one repo+branch worktree, a **workspace** = a numbered tab inside it, a **window** = a pane. Prefix = `ctrl+space`. The agent **sidebar** (rail) with the Inbox of agents that need you (`needs_input`, `errored`, finished turns) is the core — it replaces the old `claude-agent-presence` stack. Agent state comes from `tuios agent-hook claude-code` hooks in `.chezmoitemplates/claude-settings.json`; tuios `[notifications.agent]` is the only notifier (the Claude Stop hook that played sounds is gone). Worktrees via the `work` CLI (`new`/`ls`/`switch`/`rm`/`pr`); `work new` / `work switch` are thin wrappers over **`bin/workctl`** (`scriptc/workctl.ts`), the one branch / PR command that `prefix+shift+g`, `prefix+shift+o`, gh-dash's `w` and lazygit's `w` all open — see `docs/tuios.md`. Nav: `prefix+w` session picker · `prefix+g` goto · `prefix+a` / `prefix+0` next item that needs you · `prefix+t` pane finder · `prefix+h/j/k/l` windows. Config: `dot_config/tuios/config.d/readonly_10-dotfiles.toml.tmpl` (live is `~/.config/tuios/config.d/10-dotfiles.toml`; `config.toml` is what the settings page writes, tracked as `dot_config/tuios/config.toml`: `chezmoi re-add` it after clicking). Full reference: `docs/tuios.md`.
- **tmux and herdr removed** (tmux 2026-08-18, herdr on the switch to tuios). tuios is the only multiplexer on Mac and lab. The pre-herdr state is at git tag `pre-herdr` / branch `pre-herdr-backup`; herdr is only in git history. No herdr shim: scripts call `tuios` directly.
- **`disk-sweep` is manual only** (Greg, 2026-09-25): Docker images (22.8 GB reclaimable at the time), `~/.npm`, stale worktrees. Worktree cleanup goes through `workctl prune`, which calls it. Do not schedule it (no launchd, no cron).
- **`ctrl+space` stolen by the input-source switcher, or Collie broken / pairing a phone** → read `docs/tuios.md` (sections "ctrl+space and input sources", "Collie (phone)") first.

## Shell history (nushell)

- **`Ctrl+R` = fzf** over the nushell sqlite history (`dot_config/nushell/autoload/fzf-history.nu`). `Alt+T` = Television smart-autocomplete (`tv.nu`). TV's `nu-history` channel is **not** wired to Ctrl+R — its filter quality is too weak.
- **Do not propose Atuin** until upstream nushell issues close: [atuinsh/atuin#2900](https://github.com/atuinsh/atuin/issues/2900) (executehostcommand pastes literal text) + [#2820](https://github.com/atuinsh/atuin/issues/2820) (nu integration broken). Both still open as of 2026-05-16. Re-verify with `gh issue view` before recommending.

## Lab (`minis`, Debian) — connect & cold-start

- SSH alias: `ssh mrglaszki` (chezmoi-templated `~/.ssh/config`), `HostName 192.168.50.10` on purpose: AdGuard runs on that host, so ssh must not depend on its DNS. The old `lab` name and the `lab` / `*.lab` DNS rewrites were removed 2026-10-23; DNS `mrglaszki` → 192.168.50.10 is an AdGuard rewrite.
- **tuios runs on the lab too.** Preferred access from the Mac is `os-mrglaszki` (`tuios attach --host mrglaszki`, `[hosts.mrglaszki]` in the tuios config) — the lab's session is drawn in a plain Ghostty window with the local keys and theme, nothing nested; run it outside a tuios pane. Full remote flow in `docs/tuios.md`.
- **One-time terminfo install per remote** so nvim accepts `xterm-ghostty`:
  ```
  infocmp -x xterm-ghostty | ssh <host> -- tic -x -
  ```
- Lab login shell is `bash`, not nu. Either run `nu` after login or `chsh -s $(which nu)` (after adding nu to `/etc/shells`).
- **Pulling new dotfiles on lab from bash:** `chezmoi update` (runs `git pull` in `~/.local/share/chezmoi` + `chezmoi apply`). `~/Code/dotfiles` on lab is NOT a git checkout.

## Pointers

- `docs/dotfiles-inventory.md` — full inventory of what's tracked
- `docs/new-mac.md` — step order for moving to a new Mac, with the traps hit on 2026-10-19
- `docs/agents-sync.md` — agent-* sync internals
- `docs/mcp-clients-setup.md` — MCP setup per client
- `docs/secrets.md` — secret management workflow
- `docs/setapp-apps.md` — Setapp app handling
- `docs/streamdeck.md` — Stream Deck + layout + Homey office control
- `README.md` — public-facing intro (keep CLAUDE.md as the operational source)
