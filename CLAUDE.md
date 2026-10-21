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
├── dot_config/                     # → ~/.config (nushell, herdr, nvim, ghostty, sketchybar, ...)
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

**Two former sources of permanent fake drift, both fixed 2026-08-20 — don't reintroduce them:**

- **umask.** chezmoi inherits the umask of whatever process ran it, so an apply from a umask-077 shell wrote every managed dir `0700` and the next apply from umask-022 wanted `0755` back — ~816 rows of pure mode churn that `bin/sync` could only bulldoze with `--force`. `umask = 0o022` is now pinned top-level in `~/.config/chezmoi/chezmoi.toml` **and** in the generator in `bootstrap.sh`. `private_*` entries still get `0700`/`0600`.
- **`bin/` exec bit.** chezmoi takes a target's exec bit from the source *filename* (`executable_foo`), never from the source file's mode — so all 41 scripts (755 on disk, no prefix) landed in `~/bin` at `0644`. Invisible on the Mac, fatal on the lab where `~/bin/sync` **is** `sync`/`chezmoi`. Fixed by ignoring `bin/**` and rsyncing it (stage 28). Do **not** rename them to `executable_*`: `bin/` doubles as a PATH dir and ~10 launchd plists, `herdr/config.toml` and sketchybar items hardcode `~/Code/dotfiles/bin/<name>`.

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

#### Browser automation — two stacks (Mac)

| Stack | Reach for it when | Source of truth |
|---|---|---|
| `agent-browser` (skill, Chrome/CDP) | **Quick shot, no human needed** — public page, docs scrape, DOM read, test a deployed page. Cheaper in tokens. | `agent-skills/agent-browser/` |
| **`bsk`** (BrowserSkill → Comet Agent Window) | **Greg wants to watch, joint research, behind a login, or bot-blocked/captcha.** Also long multi-step flows. | `run_onchange_after_27-browserskill.sh.tmpl` + `agent-skills/bsk/` |

Policy: `agent-rules/browserskill-agent-window.md`. Install, `bsk doctor`, skill refresh and the retired `claude-in-chrome`: `docs/browser-automation.md`.

### Skille z skills.sh (ephemeral)

Jednorazowa wiedza domenowa idzie przez **`skill-scout`** → `npx skills use <owner/repo@skill>`, który wypisuje SKILL.md na stdout i **niczego nie instaluje**. `npx skills add` jest zakazany — pisze do `~/.claude/skills/`, które `run_onchange_after_30` czyści przez `rsync --delete`, więc skill i tak zniknie, a do tego czasu obciąża kontekst każdej sesji.

Żeby obcy skill został na stałe: `cp -r <temp-dir>/<skill> agent-skills/<skill>` + commit. `agent-skills/` jest jedynym źródłem prawdy.

## Secrets & private data

- `private/` — gitignored staging area, restored to `~/` by `run_after_05`
- `private_dot_ssh/` → `~/.ssh` at mode 0600 (templated)
- **Work identifiers (employer, team, roster, Slack IDs, client names) NEVER go in this repo** — it's public. They live in `~/.local/state/dotfiles/secrets/{work-context.md,work.env}` + `.chezmoidata/private-work.toml` (gitignored), all restored from 1Password (see `docs/secrets.md` → "Work identifiers"). Skills reference *work-context*; scripts read `WORK_*` env vars; templates use `{{ index . "work" ... }}`.
- **A local edit to a restored secret file dies on the next `bin/sync`.** `run_after_05` runs on every apply and does `op document get --force`, so `work-context.md`, `work.env` and the rest come back from the vault. Push the edit first — `op document edit <ITEM> <file> --vault Dotfiles` (item names in `docs/secrets.md`) — then `op document get` it to a scratch file and `cmp` it against the local file, and only then sync.
- Private skills/rules (client/product-specific) go in the `PRIVATE_AGENT_ASSETS_TAR` 1Password overlay, not `agent-skills/`/`agent-rules/`.
- `.gitleaks.toml` — public scanner rules; private identifier rules in `~/.local/state/dotfiles/secrets/gitleaks-private.toml`. Enforced by **tracked hooks** `scripts/git-hooks/{pre-commit,pre-push}` (wired via `core.hooksPath` by `run_onchange_after_36`); both block when the private config is missing. Manual full scan: `bin/gitleaks-dotfiles`.
- Templated secrets in `*.tmpl` files use chezmoi's secret functions (1Password on Mac, see `docs/secrets.md`)
- `1Password CLI` on Linux is **not** in homebrew — install via apt (see Linux block in `dot_Brewfile.tmpl`)

## sketchybar (Mac)

- **Verify a change with `bin/sketchybar-restart`**, not `--reload` plus one `--query`. Its probe checks every expected item and fails when sketchybar sits above 20% cpu, which is how an event loop shows (2026-10-19: a `forced` handler calling `--update` held 85% cpu while every item looked fine). Add new items to its `EXPECTED` list.
- **`--update` fires `forced`.** Never call it (or `--trigger forced`) from a `forced` handler unless a state change guards it, as `items/compact.lua` does.
- **Per-display questions start with `--query displays`.** An item's `geometry.drawing` is global; which screens show it is `associated_display_mask` (bit n = display n), and `display=2,3` takes a list. "The title still shows on the laptop" was two monitors plugged in, ~6 calls to find.
- **Laptop vs monitor layout lives in `items/compact.lua`** and is decided per bar, not per display: compact only when the built-in screen is the only one; with the lid open next to monitors every bar gets the full layout and the laptop's items may hide under the notch (Greg's pick, 2026-10-20). Widgets read `settings.compact`.

## Multiplexer — herdr (Mac)

- **`hd` / `herdr` is the launcher** (`dot_config/nushell/autoload/herdr.nu` → `hd`, `hd-restart`, `hd-stop`, `hd-lab`). Prefix = `ctrl+space`. The priority-sorted **agent sidebar** (blocked-first) is the core — it replaces the old `claude-agent-presence` stack and the window-wrappers. Worktrees via the herdr-native `work` CLI (`new`/`ls`/`switch`/`rm`/`pr`); `work new` / `work switch` are thin wrappers over **`bin/workctl`** (`scriptc/workctl.ts`), the one branch / PR command that `prefix+shift+g`, `prefix+shift+o`, gh-dash's `w` and lazygit's `w` all open — see `docs/herdr.md`. Nav: `prefix+w` workspace picker · `prefix+g` goto · `prefix+a` agent-cycle · `prefix+0` jump-to-waiting-agent · `prefix+h/j/k/l` panes. Config: `dot_config/herdr/config.toml`. Full reference: `docs/herdr.md`.
- **tmux removed** (2026-08-18). herdr is the only multiplexer on Mac and lab; the old `dot_config/tmux/`, `brew "tmux"`, TPM install script and tmux statusline scripts are gone. Pre-herdr state remains reachable at git tag `pre-herdr` / branch `pre-herdr-backup` if ever needed.
- **Every gh-dash `command:` must be one shell-agnostic command.** gh-dash runs custom keybinding commands through `$SHELL -c`, and in a herdr pane `$SHELL` is nushell — `cd …`, `;`, `&&`, `2>/dev/null` and other POSIX-only syntax parse-error and exit 1 *before* the command runs. Pass paths as flags instead (`workctl --repo-path …`, not `cd <path>; workctl`). Broke the `T` keybinding in `dot_config/private_gh-dash/config.yml.tmpl` (fixed 2026-09-22). The same applies to anything sent with `herdr pane run` or typed by `workctl`'s bootstrap — wrap POSIX syntax as `sh -c '…'` (fixed in `workctl` 2026-09-23).
- **git `fsmonitor--daemon` leaks per worktree.** Every worktree and every nvim plugin repo starts its own daemon; 63 stray ones were found on 2026-09-25, and one left on a removed worktree made `work rm` fail with `fatal: fsmonitor--daemon is already running`. `workctl rm` runs `git fsmonitor--daemon stop` first (safe when none is running), and `core.fsmonitor` is off for plugin and temp repos through the `includeIf` file `~/.config/git/no-fsmonitor`.
- **A worktree dir holding only `.claude/skills/` is a `bin/sync` husk.** Stage 30 placed work skills into a tree that `work rm` was deleting at the same moment, so the dir outlived its `.git` and is missing from `git worktree list` (2026-10-06). `workctl rm` sweeps husks (0c2c9d0) and takes the same `flock` as stage 30's placement, so just run `work rm` again; no manual `rm -rf`.
- **`disk-sweep` is manual only** (Greg, 2026-09-25): Docker images (22.8 GB reclaimable at the time), `~/.npm`, stale worktrees. Worktree cleanup goes through `workctl prune`, which calls it. Do not schedule it (no launchd, no cron).
- **Collie: check the bridge before handing out a pairing code.** There is no `collie` on PATH: the CLI is `bin/collie` inside the plugin checkout (`~/.config/herdr/plugins/github-installations/herdr.collie-*/*/checkout/`), or `herdr plugin action invoke <action> --plugin herdr.collie`. `collie status` shows `tailnet https://<host>.ts.net`, `curl` there answers 200, and `~/.config/herdr/plugins/config/herdr.collie/collie.log` has no `host not allowed` / `no host for this node`. Only then `collie pair` (one-time, 10 min). An error on the phone → read the bridge log, don't mint a new code (two dead codes on 2026-10-19).
- **`workctl` branch pickers must exclude any branch checked out in another worktree, the root checkout included.** `git worktree add` and `herdr worktree create` refuse it, and picking `main` from the list produced a raw JSON error that took ~130 tool calls to diagnose (2026-09-24). Selecting `main` is the regression case to try after touching the picker.

## Shell history (nushell)

- **`Ctrl+R` = fzf** over the nushell sqlite history (`dot_config/nushell/autoload/fzf-history.nu`). `Alt+T` = Television smart-autocomplete (`tv.nu`). TV's `nu-history` channel is **not** wired to Ctrl+R — its filter quality is too weak.
- **Do not propose Atuin** until upstream nushell issues close: [atuinsh/atuin#2900](https://github.com/atuinsh/atuin/issues/2900) (executehostcommand pastes literal text) + [#2820](https://github.com/atuinsh/atuin/issues/2820) (nu integration broken). Both still open as of 2026-05-16. Re-verify with `gh issue view` before recommending.

## Nushell autoload gotchas (`dot_config/nushell/autoload/`)

Three of these cost a debug loop each while writing `firefly.nu` (nu 0.115.1):

- **`$nu.home-path` does not exist** — use `$env.HOME`. `$nu` has no home field.
- **`mktemp -d -t <name>` needs an `-XXXXXX` suffix in the template**, e.g. `mktemp -d -t "firefly-import-XXXXXX"`.
- **Watch string interpolation around `(ansi …)`** — `print $"...(ansi green)..."` parses the parenthesised call, so any stray parenthesis in the literal breaks the whole string.
- **A newly added autoload file does not load in an already-open session.** `bin/sync` copies it, but you need a fresh terminal (or `source` it by hand) before the command exists.
- Interactive pickers inside a command: `input list --multi` works and is the house pattern (see `firefly.nu`).

## Lab (`minis`, Debian) — connect & cold-start

- SSH alias: `ssh lab` (chezmoi-templated `~/.ssh/config`); fallback `ssh lab-via-ip` (192.168.50.10).
- **herdr runs on the lab too.** Preferred access from the Mac is `hd-lab` (`herdr --remote lab --remote-keybindings server`) — a client-server attach to the lab's herdr server from a plain Ghostty window (not nested in a local herdr). Full remote flow in `docs/herdr.md`.
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
