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
├── dot_config/                     # → ~/.config (nushell, herdr, nvim, ghostty, sketchybar, ...)
├── dot_cursor/                     # → ~/.cursor
├── private_dot_ssh/                # → ~/.ssh (mode 0600, templated)
├── agent-plugins/plugins.json.tmpl # Claude Code plugin install list
├── agent-mcp/mcp-servers.json.tmpl # Claude Code MCP server list
├── agent-rules/                    # synced into ~/.claude (and ~/.cursor) as rule docs
├── agent-skills/                   # synced into ~/.claude/skills + ~/.cursor/skills
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
| 15 | `run_onchange_after_15-macos-nushell-application-support.sh.tmpl` | macOS-only nushell support |
| 20 | `run_onchange_after_20-macos-xdg-launchagent.sh.tmpl` | macOS XDG launch agent |
| 25 | `run_once_after_25-install-claude.sh.tmpl` | Install Claude Code CLI |
| 27 | `run_onchange_after_27-browserskill.sh.tmpl` | Install the `bsk` CLI (BrowserSkill), macOS only |
| 28 | `run_onchange_after_28-bin-exec-bits.sh.tmpl` | rsync `bin/` → `~/bin` (keeps the exec bit; `bin/**` is chezmoi-ignored) |
| 29 | `run_onchange_after_29-scriptc-build.sh.tmpl` | compile `scriptc/*.ts` → native binaries in `bin/` + `~/bin` |
| 30 | `run_onchange_after_30-agent-skills-sync.sh.tmpl` | rsync `agent-skills/` → `~/.claude/skills`, `~/.cursor/skills` |
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

Finish with `chezmoi diff` to confirm the change was captured. Don't commit until asked.

**Template-aware re-sync (live → `.tmpl`).** When the source is a `.tmpl`, live drifted, and live is the truth: `chezmoi re-add` is a no-op, so rewrite by hand. Inventory every `{{ ... }}` token in the existing template first — `.chezmoi.*`, `if eq .chezmoi.os` branches, `includeTemplate`, secret functions — copy live in verbatim, then put each token back. Verify byte-identity with `bin/render-and-diff <source.tmpl>` (exit 0 = match, 1 = diff, 2 = bad invocation). Mentally render the *other* OS branch before committing; nothing checks it automatically. Decide once whether live or the template is canonical and stop oscillating.

Live drift in `~/.claude/skills/<name>/` is **overwritten** on the next apply unless persisted back into `agent-skills/`.

## Native helpers — `scriptc/`

[scriptc](https://github.com/vercel-labs/scriptc) (vercel-labs, Apache-2.0, **experimental 0.0.x**) compiles ordinary TypeScript to a standalone native binary — no Node, no V8 in the output. Installed as an npm global by `run_onchange_after_12-npm-globals.sh.tmpl`; needs node 24+ and clang **at build time only**.

- **Source of truth is `scriptc/<name>.ts`.** Stage 29 compiles each one to `bin/<name>` and mirrors it to `~/bin/<name>`. The binaries are **gitignored** — arch-specific and ~400 KB each, so every machine builds its own. Add a `.gitignore` line per new source.
- **Output goes to `bin/`, not just `~/bin`,** because `$PATH` has `~/Code/dotfiles/bin` at position 3 and `~/bin` at 20 — the checkout shadows `~/bin` on the Mac.
- **Both machines build natively.** Mac: brew/mise node + Apple clang → Mach-O arm64, ~4.5s. Lab: linuxbrew node 26 + the `llvm` formula's clang → ELF x86-64, ~1.1s. Stage 29 must `eval` the right `brew shellenv` (`/opt/homebrew` **or** `/home/linuxbrew/.linuxbrew`) — a non-interactive lab shell sees neither node nor clang without it, which reads exactly like "the lab has no toolchain" and is wrong.
- **There is no shell fallback.** A missing toolchain fails the stage loudly. A second, hand-maintained shell twin of each helper only rots and diverges.
- `scriptc coverage <file.ts>` reports how much compiles statically before you commit to a port. `audit-drift.ts` is 100% static (57/57 statements).
- Supported at runtime: `child_process`, `fs`, `path`, `http`/`http2`, `net`, `tls`, `fetch`, `regex`, `readline`, `process` (see `packages/runtime/src/scr_*.c` upstream).

**What a port actually buys.** Measured on `audit-drift` with 200 drifted paths and `chezmoi` stubbed out, so the numbers are the wrapper's own cost: 9.8s → **0.06s** and 29.2 MB → **22.0 MB** peak RSS, ~1200 forks → 3. In real use the whole run is ~17.8s either way, because `chezmoi diff` + `chezmoi managed` dominate completely. **Port for the typed logic and for killing per-path subprocess fan-out, not for wall-clock** — if a helper is one `chezmoi`/`gh` call plus a `jq`, leave it in bash.

**Two casting footguns, found porting `claude-mcp-defaults` (2026-09-17).** Both are silent — nothing throws, the wrong thing just happens:

- **`JSON.parse(x) as SomeInterface` is not a type assertion.** scriptc *reconstructs* the value to match the interface and drops every field the interface does not declare. Casting `~/.claude.json` that way deletes `history`, `oauth`, `allowedTools` and everything else on write. Only ever cast parsed JSON to `Record<string, unknown>`.
- **A nested cast returns a detached copy, not a reference.** `data["projects"] as Record<string, unknown>` gives you a new object; mutating it leaves `data` untouched. Write the result back explicitly at every level. The tell is a run that prints "changed" while the file comes out byte-identical.

- **An atomic write drops the target's permissions.** `rename` replaces the inode, so the file keeps the *temp* file's mode, not the original's — under umask 022 a 0600 credential file comes back 0644. Bash writing in place inherited the mode for free; the TS rewrite has to ask. Pass `{ mode: 0o600 }` to `writeFileSync` **and** `chmodSync` the temp file (`mode` only applies on create). Caught by a commit security review on `claude-mcp-defaults`, which writes `~/.claude.json`.

Also: `process.cwd()` resolves symlinks, bash's `$PWD` does not. On macOS `/tmp` is a symlink, so a helper that defaults to "the current directory" needs `process.env.PWD` to match its bash original.

**Three more from the same port, surfaced by `/retro` (2026-09-18):**

- **`.toString()` on a number pulls in the dynamic engine.** `scriptc coverage` drops from 100% to 93% and the site is marked "runs with --dynamic" — a ~620 KB embedded JS engine the static build does not include, so the binary fails at that line. Use `String(n)` or template literals.
- **`JSON.stringify` leaves non-ASCII as-is.** Python's `json.dump` (the bash original's writer) uses `ensure_ascii=True` and emits `\uXXXX` for every non-ASCII code unit, surrogate pairs included. A byte-identical rewrite needs a manual escape pass after stringify.
- **`spawnSync` has no `env`, `cwd` or fd options.** Bash's `exec 9>lock; flock -w 10 9` has no direct port. `claude-mcp-defaults.ts` locks by re-invoking itself under `flock -w 10 -E 2 <lock> <self> <same args>` and exiting on the child's status.

**Probe before you port.** Each of those was caught in a throwaway `probeN.ts` under `/tmp/scriptc-probe/`, one semantic question per file, compiled and run in isolation before the real port touched `~/.claude.json`. Do the same for any construct you have not seen scriptc handle — `scriptc coverage` tells you *whether* it compiles statically, a probe tells you *what it does*.

The pattern behind all of these: **a port changes the mechanics, not just the language.** Diff the binary against the bash original on every path you can exercise, and look hardest where bash got something implicitly — file modes, `$PWD`, inherited env.

**Porting a helper that already exists in `bin/`:** the compiled binary lands on the same path as the tracked bash script, so stage 29 silently overwrites it on the next run. Do the swap deliberately — build, diff the binary against the bash original on every code path you can exercise without side effects, then `git rm --cached` the bash file (the `.gitignore` line makes the binary invisible to git, and the bash source stays in history).

## Claude-specific

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
- Claude / Cursor skills → `agent-skills/<skill-name>/SKILL.md`
- Claude / Cursor rules → `agent-rules/`

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

**`claude-in-chrome` RETIRED 2026-08-23** — kept hanging, and the two stacks
above cover it. It was never a config-file MCP (not in `agent-mcp/`); it ships
with the harness and pairs via the Chrome extension, so the only repo-side gate
is `mcp__claude-in-chrome__*` in `permissions.deny`
(`.chezmoitemplates/claude-settings.json`) — that blocks calls but the tools
still load if the extension is paired. Untrack-able off-switch (lives in
`~/.claude.json` → `claudeInChromeDefaultEnabled`): `/chrome` → turn off
"Enabled by default", or disable the extension (`fcoeoabgfenejglbffodgkkbkcdhcgfn`)
in `chrome://extensions`. Don't re-add it.

**BrowserSkill** ([Tencent/BrowserSkill](https://github.com/Tencent/BrowserSkill),
MIT) drives Greg's **real, logged-in Comet profile** from the CLI in a separate,
visible **Agent Window** — his own windows are left alone unless a tab is
explicitly `bsk tab borrow`ed. Policy lives in
`agent-rules/browserskill-agent-window.md`.

- CLI + daemon → `~/.local/bin/bsk`, state in `~/.bsk` (runtime only, not tracked).
  Upgrade with `bsk update`; health check `bsk doctor` (all rows `ok`/`N/A`).
  `agent skill up to date → N/A` is expected — see the skill bullet below.
- Extension is **hand-installed** from the [Chrome Web Store](https://chromewebstore.google.com/detail/hhcmgoofomhgciiibhipgmgkgnoenaoi)
  (id `hhcmgoofomhgciiibhipgmgkgnoenaoi`) and lives in Comet's `Default` profile.
  A script cannot install it — `0 browsers connected` in `doctor` means it's off.
- **Skill dir is `bsk`, not `browser-skill`** (renamed 2026-08-23 so Greg can
  just say "agent-browser" or "bsk" and hit the right one). It comes from
  `agent-skills/bsk/` via stage 30, **not** from `bsk install-skill` (rsync
  `--delete` would fight it). Side effect: `bsk doctor` looks for
  `~/.claude/skills/browser-skill` and now reports `agent skill up to date →
  N/A no agent skill installed`. That's by design. To refresh after `bsk update`:
  `bsk install-skill --harness claude-code --yes`, copy
  `~/.claude/skills/browser-skill/SKILL.md` into `agent-skills/bsk/SKILL.md`,
  **keep our `name: bsk` frontmatter + trigger phrases**, then `bin/sync` (the
  rsync deletes the stray `browser-skill/` dir).
- **`npm install bsk` is the wrong package** — an abandoned 2017 Vue app squatting
  that name. Only the GitHub release installer is correct.

### Skille z skills.sh (ephemeral)

Jednorazowa wiedza domenowa idzie przez **`skill-scout`** → `npx skills use <owner/repo@skill>`, który wypisuje SKILL.md na stdout i **niczego nie instaluje**. `npx skills add` jest zakazany — pisze do `~/.claude/skills/`, które `run_onchange_after_30` czyści przez `rsync --delete`, więc skill i tak zniknie, a do tego czasu obciąża kontekst każdej sesji.

Żeby obcy skill został na stałe: `cp -r <temp-dir>/<skill> agent-skills/<skill>` + commit. `agent-skills/` jest jedynym źródłem prawdy.

### Dubel `/skill` w pickerze → `bin/sync`, nie kasowanie ręczne

Stage 30 dzieli `agent-skills/` na globalne (rsync do `~/.claude/skills/`) i **project-scoped** (kopiowane do `<repo>/.claude/skills/` **i usuwane z globalnego katalogu**, żeby nie żarły kontekstu w pozostałych repo). Bukiety: `WORK_SKILLS` z `bin/place-work-skills --list` (dzielone z `work new`, żeby świeży worktree też je dostał), `DOTFILES_SKILLS`, `HOMELAB_SKILLS`. Skrypt sam dopisuje `/.claude/skills/<name>/` do `.git/info/exclude` repo docelowego.

Czyli work-scoped skill w `<work-repo>/.claude/skills/` jest **poprawny**. Bugiem jest jego kopia leżąca **równocześnie** w `~/.claude/skills/`. Tak było 2026-09-08 z ośmioma skillami (`g-pr*`, `g-github-issue`, `babysit-prs`) — `/g-pr-bump` pokazywał się dwa razy, ~830 tok/sesję na darmo. Naprawia to jeden `bin/sync`; ręczne `rm` w repo firmy wraca przy najbliższym apply, bo tak ma być. Weryfikacja: `comm -12 <(ls ~/.claude/skills | sort) <(ls <repo>/.claude/skills | sort)` ma być puste. Pełna reguła: `agent-rules/skill-scope-duplicates.md`.

Kolizje nazw z teamem **nie** są przykrywane — project scope nie shadowuje user scope, oba wpisy ładują się do pickera. Podmiana teamowego wymagałaby PR-a do repo firmy, więc fix to rename globalnego: `deslop` → `g-deslop` (2026-09-09), a `/deslop` w monorepo zostaje teamowy. Ten sam wzorzec dotyczy `grafana-mcp-wtf`.

## Secrets & private data

- `private/` — gitignored staging area, restored to `~/` by `run_after_05`
- `private_dot_ssh/` → `~/.ssh` at mode 0600 (templated)
- **Work identifiers (employer, team, roster, Slack IDs, client names) NEVER go in this repo** — it's public. They live in `~/.local/state/dotfiles/secrets/{work-context.md,work.env}` + `.chezmoidata/private-work.toml` (gitignored), all restored from 1Password (see `docs/secrets.md` → "Work identifiers"). Skills reference *work-context*; scripts read `WORK_*` env vars; templates use `{{ index . "work" ... }}`.
- Private skills/rules (client/product-specific) go in the `PRIVATE_AGENT_ASSETS_TAR` 1Password overlay, not `agent-skills/`/`agent-rules/`.
- `.gitleaks.toml` — public scanner rules; private identifier rules in `~/.local/state/dotfiles/secrets/gitleaks-private.toml`. Enforced by **tracked hooks** `scripts/git-hooks/{pre-commit,pre-push}` (wired via `core.hooksPath` by `run_onchange_after_36`); both block when the private config is missing. Manual full scan: `bin/gitleaks-dotfiles`.
- Templated secrets in `*.tmpl` files use chezmoi's secret functions (1Password on Mac, see `docs/secrets.md`)
- `1Password CLI` on Linux is **not** in homebrew — install via apt (see Linux block in `dot_Brewfile.tmpl`)

## Multiplexer — herdr (Mac)

- **`hd` / `herdr` is the launcher** (`dot_config/nushell/autoload/herdr.nu` → `hd`, `hd-restart`, `hd-stop`, `hd-lab`). Prefix = `ctrl+space`. The priority-sorted **agent sidebar** (blocked-first) is the core — it replaces the old `claude-agent-presence` stack and the window-wrappers. Worktrees via the herdr-native `work` CLI (`new`/`ls`/`switch`/`rm`/`pr`); `work new` / `work switch` are thin wrappers over **`bin/workctl`** (`scriptc/workctl.ts`), the one branch / PR command that `prefix+shift+g`, `prefix+shift+o`, gh-dash's `w` and lazygit's `w` all open — see `docs/herdr.md`. Nav: `prefix+w` workspace picker · `prefix+g` goto · `prefix+a` agent-cycle · `prefix+0` jump-to-waiting-agent · `prefix+h/j/k/l` panes. Config: `dot_config/herdr/config.toml`. Full reference: `docs/herdr.md`.
- **tmux removed** (2026-08-18). herdr is the only multiplexer on Mac and lab; the old `dot_config/tmux/`, `brew "tmux"`, TPM install script and tmux statusline scripts are gone. Pre-herdr state remains reachable at git tag `pre-herdr` / branch `pre-herdr-backup` if ever needed.

## Shell history (nushell)

- **`Ctrl+R` = fzf** over the nushell sqlite history (`dot_config/nushell/autoload/fzf-history.nu`). `Alt+T` = Television smart-autocomplete (`tv.nu`). TV's `nu-history` channel is **not** wired to Ctrl+R — its filter quality is too weak.
- **Do not propose Atuin** until upstream nushell issues close: [atuinsh/atuin#2900](https://github.com/atuinsh/atuin/issues/2900) (executehostcommand pastes literal text) + [#2820](https://github.com/atuinsh/atuin/issues/2820) (nu integration broken). Both still open as of 2026-05-16. Re-verify with `gh issue view` before recommending.

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
- `docs/agents-sync.md` — agent-* sync internals
- `docs/mcp-clients-setup.md` — MCP setup per client
- `docs/secrets.md` — secret management workflow
- `docs/setapp-apps.md` — Setapp app handling
- `docs/streamdeck.md` — Stream Deck + layout + Homey office control
- `README.md` — public-facing intro (keep CLAUDE.md as the operational source)
