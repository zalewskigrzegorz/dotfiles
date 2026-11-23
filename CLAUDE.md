# dotfiles

Personal dotfiles managed by [chezmoi](https://chezmoi.io). `chezmoi apply` must reproduce the full setup on a fresh machine (macOS workstation + Debian lab).

## Hard rules

1. **All settings live here.** Every plugin, MCP server, skill, hook, permission, keybinding, brew formula and tool config is mirrored into this repo. Something only in `~/` is invisible to `chezmoi apply` and won't survive a reinstall.
2. **Commit directly to `master`.** No feature branches, no PRs (personal repo). Finished work goes through the end-of-task commit popup (`agent-rules/commit-message-rules.md`).
3. **Add via chezmoi, not manual copy.** `chezmoi add ~/<path>` so the source naming (`dot_*`, `private_*`, `executable_*`, `.tmpl`) is right.
4. **Don't edit synced output.** When a source exists under `agent-skills/`, `agent-rules/`, `agent-mcp/`, `agent-plugins/` or `dot_*`, edit the source; `chezmoi apply` overwrites the target.
5. **Claude skills go in `agent-skills/`, NOT `dot_claude/skills/`.** Stage 30 does `rsync --delete agent-skills/ → ~/.claude/skills/`, so anything else there (live edits included) is wiped on every apply. `chezmoi add ~/.claude/skills/<x>` creates a `dot_claude/skills/<x>` that never reaches the target: `cp -r ~/.claude/skills/<x> agent-skills/<x>` instead.

## Project structure

```
~/Code/dotfiles/
├── bootstrap.sh                    # one-shot machine bootstrap (chezmoi + first apply)
├── dot_Brewfile.tmpl               # brew bundle source (templated by profile)
├── nushell-mcp.json.tmpl           # MCP servers for the nushell mcp integration
├── dot_claude/                     # → ~/.claude (settings, hooks, output-styles, statusline)
├── dot_config/                     # → ~/.config (nushell, tuios, nvim, ghostty, sketchybar, ...)
├── private_dot_ssh/                # → ~/.ssh (0600, templated)
├── agent-plugins/plugins.json.tmpl # Claude Code plugin install list
├── agent-mcp/mcp-servers.json.tmpl # Claude Code MCP server list
├── agent-mods/                     # Claude Code mods (greg-mods marketplace, guard)
├── agent-rules/                    # rendered into ~/.claude/CLAUDE.md (+ scoped/ → ~/.claude/rules)
├── agent-skills/                   # synced into ~/.claude/skills
├── bin/                            # PATH-exposed scripts
├── scriptc/                        # TypeScript compiled to native binaries in bin/ (stage 29)
├── scripts/                        # repo maintenance (not on PATH)
├── userscripts/                    # Tampermonkey userscripts for Vimma (installed from raw GitHub URL)
├── docs/                           # operational notes
├── brew/                           # brew-related helpers
├── legacy/                         # archived configs (do not edit)
├── private/                        # gitignored secrets staging area
└── run_*                           # chezmoi lifecycle hooks (see Setup order)
```

## Source naming

- `dot_*` → `~/.*`; `*.tmpl` → rendered (`chezmoi execute-template < file.tmpl` to preview)
- `private_*` → mode 0600; `executable_*` → 0755
- `run_once_*` / `run_onchange_*` / `run_after_*` → lifecycle hooks, run in numeric order

## Setup order (main stages; `ls run_*` for all)

| Stage | What it does |
|---|---|
| 00 | Homebrew (Mac + Linux) |
| 05 | restore secrets from `private/` / 1Password (every apply) |
| 10 | `brew bundle` against the rendered Brewfile |
| 13 | Mac: Touch ID for `sudo` (`/etc/pam.d/sudo_local` + `pam_reattach`) |
| 14 | Mac: defaults (Dock, hidden menu bar, Finder). The bar is Gzyms; SketchyBar not started since 2026-10-30 |
| 15 / 20 | Mac: nushell Application Support; XDG launch agent |
| 16 | Mac: SbarLua + sketchybar-app-font (sketchybar's Lua config is empty without them) |
| 25 | install Claude Code CLI |
| 26 | Serena as a uv tool (user-scope MCP, fetches its own TS server); see `agent-rules/code-indexing-proactive.md` |
| 27 | Mac: Plannotator binary (pinned, SLSA-verified); sharing off via `PLANNOTATOR_SHARE=disabled` in `env.nu.tmpl` |
| 28 | rsync `bin/` → `~/bin` (keeps exec bit; `bin/**` is chezmoi-ignored) |
| 29 | compile `scriptc/*.ts` → native binaries in `bin/` + `~/bin` |
| 30 | rsync `agent-skills/` → `~/.claude/skills` |
| 31 | `agent-rules/*.md` (`alwaysApply: true`) → `~/.claude/CLAUDE.md`; `agent-rules/scoped/*.md` (`paths:`, off the 150k startup budget) → `~/.claude/rules/`. Work-monorepo-only content goes to `scoped/` |
| 32 / 33 | apply `agent-mcp/mcp-servers.json.tmpl` / `agent-plugins/plugins.json.tmpl` |
| 34 | Mac: Collie (phone) standalone, `collie start` (`.claude/rules/tuios-config.md`) |
| 35 | Raycast shim; `gh` extensions (`EXTENSIONS` array) |
| 36 | tracked git hooks (`core.hooksPath` → gitleaks pre-commit/pre-push) |
| 43 / 46 | Mac LaunchAgents `com.greg.pr-watch`, `com.greg.pr-eyes` (every 10 min, `.claude/rules/workctl-gh-dash.md`) |
| 49 | Mac: Gzyms catalog plugins (`.claude/rules/gzyms.md`) |
| 50 | Mac: `com.greg.screens-sweep`, daily junk sweep of Drive `Screenshots` (`.claude/rules/screens-sweep.md`) |

## Common commands

```bash
chezmoi diff                       # preview pending changes (run before commit)
chezmoi apply                      # apply repo → live (idempotent)
chezmoi update                     # git pull + apply (use on lab)
chezmoi add ~/<path>               # track a new file
chezmoi re-add ~/<path>            # update tracked file from live
bin/sync                           # ensures PATH, then chezmoi apply
bin/gitleaks-dotfiles              # scan repo for leaked secrets
```

## Drift audit & adding apps

**`bin/audit-drift` first** (compiled from `scriptc/audit-drift.ts`, gitignored: edit the `.ts`). It classifies `chezmoi diff` without loading content:

- `FILE_DRIFT` → `chezmoi re-add`. `BINARY_DRIFT` → same, but `re-add` can drop the exec bit without an `executable_` prefix.
- `TEMPLATE_DRIFT` → `re-add` may no-op; rewrite the `.tmpl` by hand (`.claude/rules/chezmoi-templates.md`).
- `FAKE_SCRIPT` → a `run_*` that executes every apply; not drift.

Healthy `chezmoi status` is ~2 `R` script rows; more is real drift. Fake-drift traps (`docs/dotfiles-inventory.md` → "Fake drift"): keep `umask = 0o022` pinned in `chezmoi.toml` + `bootstrap.sh`, never rename `bin/*` to `executable_*`.

Beyond it, compare live vs repo and classify each row `LIVE_ONLY` (add), `REPO_ONLY` (apply, or intentional removal), `MODIFIED` (`re-add` live→repo / `apply` repo→live). Order: edit `.tmpl`s, then `re-add`, then `bin/sync`; verify with an empty `chezmoi diff`. Check `.chezmoiignore` before flagging "missing".

| What | Live | Repo (where a new one goes) |
|---|---|---|
| brew formulae / casks / taps | `brew leaves`, `brew list --cask`, `brew tap` | `dot_Brewfile.tmpl`, matching section, alphabetical (`brew info` first; grep the rendered template, entries hide behind `{{ if }}`) |
| Claude plugins | `claude plugin list` | `agent-plugins/plugins.json.tmpl` |
| MCP servers | `claude mcp list` | `agent-mcp/mcp-servers.json.tmpl`, `nushell-mcp.json.tmpl` |
| skills | `ls ~/.claude/skills/` | `agent-skills/` (`cp -r`, hard rule 5) |
| hooks / output-styles | `ls ~/.claude/{hooks,output-styles}/` | `dot_claude/{hooks,output-styles}/` |
| `gh` extensions | `gh extension list` | `EXTENSIONS` in `run_onchange_after_35-gh-extensions.sh` (never `gh extension install` alone: `~/.local/share/gh/` is untracked) |
| any other dotfile / app config | | `chezmoi add <path>`, then check the prefix |

A bundle Greg hands over (zip, patch, README): map every part its README lists to a target, report "N of M installed, missing: X", check the effect where Greg looks (536b9fd3). Finish with `chezmoi diff`, then the commit popup.

## Native helpers — `scriptc/`

Read `scriptc/CLAUDE.md` (loads with `scriptc/`) before editing any `scriptc/*.ts`.

## Claude-specific

Global Claude config: `dot_claude/` → `~/.claude/`.

- **Settings live in `.chezmoitemplates/claude-settings.json`**; `dot_claude/modify_settings.json.tmpl` is a `modify_` script that merges the managed keys into live `~/.claude/settings.json`. There is no `dot_claude/settings.json.tmpl`.
- `keybindings.json`, `hooks/`, `output-styles/`, `executable_statusline.sh`; `skills/` is filled by stage 30 (edit `agent-skills/`).
- Testing a `pre-tool-use/*` hook: `.claude/rules/claude-hooks.md`.
- **ponytail band**: `/ponytail band [off]`; state `~/.claude/.ponytail-band`, tracked as `dot_claude/dot_ponytail-band`. Its buttons need the mouse, absent with the alt screen off. Never patch `register.tsx`. A running session keeps the old band until `/exit` + `claude --continue`.
- **Skills from skills.sh** are ephemeral: `skill-scout` → `npx skills use <owner/repo@skill>` (guard blocks `npx skills add`). Permanent: `cp -r <temp-dir>/<skill> agent-skills/<skill>` + commit.
- Browser automation sources: `.claude/rules/browser-automation.md`; when to use which: `agent-rules/browser-stacks.md`.

## Secrets & private data

- `private/` — gitignored staging, restored to `~/` by stage 05; `private_dot_ssh/` → `~/.ssh` (0600, templated). Templated secrets use chezmoi's 1Password functions (`docs/secrets.md`). 1Password CLI on Linux comes from apt, not brew.
- **Work identifiers (employer, team, roster, Slack IDs, client names) NEVER go in this repo** — it's public. They live in `~/.local/state/dotfiles/secrets/{work-context.md,work.env}` + gitignored `.chezmoidata/private-work.toml`, restored from 1Password. Skills reference *work-context*; scripts read `WORK_*`; templates use `{{ index . "work" ... }}`. Private skills/rules go in the `PRIVATE_AGENT_ASSETS_TAR` overlay, not `agent-skills/`/`agent-rules/`.
- **A local edit to a restored secret file dies on the next `bin/sync`** (stage 05 runs `op document get --force` every apply; same for the overlay tar). Push first: `op document edit <ITEM> <file> --vault Dotfiles` (names in `docs/secrets.md`), `op document get` to scratch and `cmp`, then sync. The push needs Greg's 1Password approval: when he's away leave the `*.pending.tar`, end with "powiedz zatwierdzę", never re-fire the prompt.
- `.gitleaks.toml` is public; private identifier rules live in `~/.local/state/dotfiles/secrets/gitleaks-private.toml`. The tracked hooks `scripts/git-hooks/{pre-commit,pre-push}` block when it's missing.

## Multiplexer — tuios (Mac + lab)

- **tuios is the only multiplexer.** tmux and herdr are removed (pre-herdr state: tag `pre-herdr`); no shim, scripts call `tuios` directly. Session = one repo+branch worktree, workspace = numbered tab, window = pane. Prefix `ctrl+space`.
- Nav: `prefix+w` sessions · `prefix+g` goto · `prefix+a` orchestrator · `prefix+0` next item that needs you · `prefix+t` pane finder · `prefix+h/j/k/l` windows.
- Worktrees: the `work` CLI (nushell) wraps `bin/workctl` (`scriptc/workctl.ts`). Config, agent sidebar and Collie details: `.claude/rules/tuios-config.md`, full reference `docs/tuios.md` (also for `ctrl+space` stolen by input sources, Collie / phone pairing).
- **`disk-sweep` is manual only** (Greg, 2026-09-25); worktree cleanup goes through `workctl prune`. Never schedule it.

## Lab (`minis`, Debian)

`ssh mrglaszki`; pull dotfiles with `chezmoi update` (`~/Code/dotfiles` there is not a git checkout). Cold start, terminfo, `run_*` PATH: `.claude/rules/lab.md`.

## Path-scoped notes — `.claude/rules/`

File-specific gotchas load on demand from `.claude/rules/*.md` (`paths:` frontmatter). Put new ones there, not here: instruction files share a 150k-char budget.

## Pointers

- `docs/dotfiles-inventory.md` — full inventory of what's tracked
- `docs/new-mac.md` — moving to a new Mac, traps from 2026-10-19
- `docs/agents-sync.md` — agent-* sync internals; `docs/mcp-clients-setup.md` — MCP per client
- `docs/secrets.md`, `docs/setapp-apps.md`, `docs/streamdeck.md` (Stream Deck + Homey office control)
- `README.md` — public intro (CLAUDE.md is the operational source)
