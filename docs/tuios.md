# tuios — agent multiplexer

[tuios](https://tuios.dev) is a Go terminal multiplexer with a native **agent rail**
(sessions grouped by state) and an **Inbox** of every agent that needs you. It replaced
herdr, which replaced tmux and the hand-built `claude-agent-presence` stack. Upstream
docs: <https://tuios.dev/docs>; the same guide for agents ships in the binary
(`tuios --skill`, topics `panes`, `fleet`, `inbox`, `errors`, `recipes`).

## Status

tuios is the only multiplexer on Mac and lab. tmux was removed 2026-08-18
(`git tag pre-herdr` / branch `pre-herdr-backup` still reach that state); herdr went with
the switch to tuios and lives only in git history. There is **no herdr shim**: every script
calls `tuios` directly. `claude-agent-presence` (sketchybar chip, `bin/claude-agent-*`,
`tmux-window-jump`) and the sesh family (`bin/sesh*`, `sesh.nu`, `dot_config/sesh`,
`claude-focus-session`) stay decommissioned.

## Vocabulary

| herdr | tuios | Notes |
|---|---|---|
| workspace | **session** | one per repo+branch worktree, named `<repo>-<branch>` (`/` → `-`) |
| tab | **workspace** | numbered slots 1–9 inside a session; `workctl` makes `nu` and `claude` |
| pane | **window** | a target is `-s <session> -w <window>`: id, 8-char id prefix, index or name |
| `blocked` | `needs_input` | the other state that needs you is `errored`; a finished turn nobody looked at is `done` |

Env in every pane: `TUIOS_SESSION`, `TUIOS_PANE_ID` (= `TUIOS_WINDOW_ID`), `TUIOS_SOCKET`,
`TUIOS_HOST`, `TUIOS_ENV=1`. `HERDR_*` variables no longer exist.

## Install + config

- `brew "tuios"` in `dot_Brewfile.tmpl` (Mac + lab).
- Managed settings: `dot_config/tuios/config.d/readonly_10-dotfiles.toml.tmpl` →
  `~/.config/tuios/config.d/10-dotfiles.toml`, read-only on purpose. tuios owns
  `config.toml` (settings page, keybind manager, `tuios pair`, `tuios hosts add` write
  there); `dot_config/tuios/create_config.toml` only creates it once, because tuios reads
  `config.d/` only when a `config.toml` exists.
- A saved config applies by itself; `hd-reload` (`tuios config apply`) pushes what waits
  (a new host, wider grants). `hd-restart` (`tuios restart-server`) only after an upgrade,
  from outside tuios.
- nu is the shell (per-OS path in the template), no tuios theme: panes keep Ghostty's
  Mocha Neon palette, the terminal-mode border is mauve `#B347FF`.
- `[daemon] resume_agents = "auto"` is the "continuum for agents": after a daemon restart tuios
  types each harness's resume command (`claude --resume <id>`).
- Launcher: plain `tuios` (start/attach). Helpers in `dot_config/nushell/autoload/tuios.nu`: `hd-reload`,
  `hd-restart`, `hd-stop` (`tuios kill-server`), `hd-mrglaszki`.

## Key bindings (prefix `ctrl+space`, keys kept from herdr)

| Key | Action |
|---|---|
| `prefix+q` | detach · `prefix+s` settings · `prefix+:` command palette (`ctrl+p` belongs to nu/nvim) |
| `prefix+w` / `prefix+g` | session picker / goto · `N` new session · `W` rename · `D` close · `,` `.` prev/next |
| `prefix+a` / `prefix+0` | jump to the next item that needs you (Inbox) · `prefix+A` next unseen finished turn |
| `prefix+c` `T` `X` | new / rename / close workspace (tab) · `1`–`9`, `p`, `n` switch |
| `prefix+h/j/k/l` | focus window · `prefix+tab` next · `` prefix+` `` last · `P` rename window |
| `prefix+v` / `\` / `\|` | split right |
| `prefix+t` | pane finder (tree: sessions, workspaces, windows) |
| `prefix+/` (or `[`) | copy mode = search: `/phrase` · `n`/`N` · `q` out. Sees only the current screen of fullscreen apps (Claude: use `ctrl+o` then `/`). `prefix+E` (scrollback in editor) is unbound: it garbles the screen on 0.11.1 |
| `bg:` windows | a background command's log in `less +F`: `ctrl+c` stops following, `/` search, `F` follow again, `q` close |
| `prefix+u` / `prefix+f` | hints: label every pane's text, `ctrl+label` opens a URL in the browser or a path in `$EDITOR` |
| `prefix+o` | review overlay: what the agent in this window changed, notes sent back as one message |
| `prefix+e` | nvim scratch (one nvim that survives the toggle) |
| `prefix+shift+r` | layout menu (50–90 % sizes) |
| `prefix+shift+g` | **branch / worktree picker** in the focused repo (`bin/tuios-worktree-new` → `workctl`) |
| `prefix+shift+o` | the same picker `--all` (other repos' worktrees too) |
| `prefix+d` | remove this session's worktree (`tuios worktree rm`; refuses uncommitted changes) |
| `prefix+m` | Tokscale token-usage dashboard (popup, `bunx tokscale@latest`) |
| `prefix+r` | tape picker (`bin/tuios-tape-pick`): fzf over `~/.config/tuios/tapes` (public, `dot_config/tuios/tapes/`) and `~/.local/state/dotfiles/secrets/tuios-tapes` (private, `PRIVATE_AGENT_ASSETS_TAR`), `tuios tape exec` of the pick in this session. `[tape] autorun = "off"`: a repo's `.tuios.tape` never offers itself |

Every split is equalised when a window opens or closes (`[hooks]` in the config).
Key search: `tuios keybinds` and the settings page (`prefix+s`).

## The branch picker — one flow, four triggers

`bin/workctl` (source: `scriptc/workctl.ts`) is the single entry point
for "get me onto a branch". One fzf window: every branch and worktree of the
repo is a row, Enter does the obvious thing for that row, and the alternatives
sit on keys.

| Key | What it does |
|---|---|
| `enter` | check out into a worktree, cloning `.env` + `node_modules` from the parent checkout (APFS `cp -c`) |
| `ctrl-l` | check out bare — no seeding |
| `ctrl-s` | check out, then run the repo's own bootstrap (`utils/secrets.sh` if present, then the lockfile's install) in its own workspace |
| `ctrl-n` | create a branch named exactly what was typed, skipping the commitlint type prefix |
| `ctrl-d` | diff against the base ref → pager |
| `ctrl-x` | remove the worktree and the branch |
| `ctrl-p` | hand the branch's PR to `work pr` |
| `ctrl-o` | open the PR (or the branch) in the browser |

Triggers, all landing on the same binary:

| From | How |
|---|---|
| shell | `work new` / `work switch` / `work sw` (thin wrappers in `work.nu`) |
| tuios | `prefix+shift+g`, `prefix+shift+o` |
| gh-dash | `w` in the branches view |
| lazygit | `w` on a local branch, remote branch or worktree |

The commitlint types are rows: typing `billing-page` in a repo that enforces them offers
`feat/billing-page`, `fix/billing-page` and the rest, with `create` in the row text so real
branches always outrank them. It is a compiled binary rather than more nushell because
gh-dash and lazygit cannot see nushell's autoload dir, and because fzf re-runs the row
generator on every keystroke (~10 ms per keystroke over 2800 branches).

**Where things live.** Worktrees stay in `~/Code/tree/wt-<repo>/<branch>`; `workctl` uses plain
git for them, not `tuios worktree new` (which would put them under
`~/.local/share/tuios/worktrees/` and skip the seed). Each worktree gets one tuios session
`<repo>-<branch>` with a `nu` and a `claude` workspace. `~/.herdr/worktrees` is still scanned,
only so old trees can be listed and removed. `workctl rm` kills the session last, after the
tree and the branch are gone. The pickers run in a popup, so every pane needs the `admin`
grant: `[agents.permissions] mode = "open"` in the config (a strict mode would break them).

## Agent state, notifications, the Inbox

- **State** comes from `tuios agent-hook claude-code --integration 3`, wired for every Claude
  hook event in `.chezmoitemplates/claude-settings.json` (it replaced
  `herdr-agent-state.sh`). It reports `working` / `needs_input` / `idle` / `done` / `errored`,
  the conversation id for `resume_agents`, and subagents. Check with `tuios list-agents
  --all-sessions` and `tuios doctor`.
- **Notifications:** `[notifications.agent]` (needs_input, errored, done; not for the window you
  are looking at; `settle_seconds = 3`; no sound) is the **only** notifier. The Claude Stop hook
  `stop.sh` (sounds + OSC 9 after every turn) was deleted on purpose.
- **Inbox** (`prefix+a`, the agents view): approvals, questions, mail, errored agents and unseen
  finished turns across every session and host; `tuios list-attention` is the CLI view.
  Answer from the phone through Collie (below).
- **PR chip:** the `$pr` token of the rail row is reported per window with
  `tuios set-agent-meta --source greg`.

## Agents from the shell

Orchestration recipes live in the `tuios-orchestration` skill: `tuios start-agent`, `queue`,
`ask-agent`, `wait-for agent-state`, `peek-prompt` / `respond`, plus `agent-status`.
Reading a window: `tuios-peek` (skill `tuios-peek`, wraps `tuios capture-pane`). A command Greg
runs himself (`sudo` steps): `tuios split-window horizontal -w "$TUIOS_PANE_ID" --name do-wpisania`,
then `tuios send-text -w <new> '<cmd>'` with no newline. A one-off secret: `tuios popup --wait --
secret-in <scratchpad>/secrets/<name>` (`agent-rules/ops-traps.md`).

## Tab / window naming (our own)

- `work` / `workctl` name a worktree's workspaces (`󰚩 claude`, ` nu`).
- `zz-tuios-tui-wrappers.nu`: `lg`, `dash`, `nvim`, `lazydocker`, `btop` rename the *current*
  workspace to a nerd-font icon while the TUI runs and restore the old name on exit.
- `dot_claude/hooks/stop/tuios-claude-title.sh` (Stop hook, Haiku) names the Claude workspace
  with a 3–4 word task title through `bin/hd-title` (`tuios set-workspace-name`) and puts the same
  title on the agent's window (`tuios set-window --name`), which the rail's agent row draws in
  place of workctl's `claude review`; it also feeds the statusline. `CLAUDE_TUIOS_TITLE_MAX` trims it. Rule: `agent-rules/hd-tab-title.md`.

## url / of pickers

`prefix+u` / `prefix+f` are tuios hints (above). In a shell, `url` and `of`
(`autoload/tuios-pick.nu`) fzf-pick a URL → browser or a file path → nvim from the current
window's scrollback (`tuios capture-pane`).

## Collie (phone)

Collie is the phone PWA over the tailnet: which agent is blocked, answer it, push. It is a
**standalone install**, not a tuios plugin (`tuios plugins install` refuses to run in a pane
and a plugin waits for a per-machine approval, so `chezmoi apply` could not reproduce it):
`run_after_34-collie.sh` installs it, writes `~/.config/herdr/plugins/config/herdr.collie/.env` (Collie reads it before `~/.config/collie`) with
`COLLIE_MUX=tuios` + the daemon socket, and runs `collie start` (service + `tailscale serve`).
Pairings live in `~/.local/state/collie`, so a phone paired under the old herdr plugin stays
paired. Two steps stay manual: "Enable HTTPS" once in the tailnet admin console, and
`collie pair` (code shown once, valid 10 min). Diagnose with `collie doctor` and
`collie status`.

- **Collie after a Mac restart: Tailscale first.** `tailscale status --json` with `BackendState: Stopped` → `tailscale up --accept-routes`; `no host for this node` in the bridge log is then a symptom, not the allowlist. Phone can't reach Collie while the bridge answers on the tailnet → `tailscale ping <iphone>` from the Mac; a timeout on an "online" phone is a hung iOS tunnel: Settings → General → VPN & Device Management → VPN → status off/on, then airplane mode, then a phone restart (6f32e82c).
- **Collie: check the bridge before handing out a pairing code.** Collie is a standalone install (`run_after_34-collie.sh`, `COLLIE_MUX=tuios` in `~/.config/herdr/plugins/config/herdr.collie/.env` (Collie reads it before `~/.config/collie`)), `collie` is on PATH via `~/.local/bin`. `collie doctor` first; `collie status` shows `tailnet https://<host>.ts.net`, `curl` there answers 200, and the bridge log has no `host not allowed` / `no host for this node`. Only then `collie pair` (one-time, 10 min). An error on the phone → read the bridge log, don't mint a new code (two dead codes on 2026-10-19).

## ctrl+space and input sources

- **`ctrl+space` taken by the input-source switcher** (hotkeys 60/61, once a second layout is added): `defaults write … AppleSymbolicHotKeys` + `activateSettings -u` + `killall TextInputSwitcher` do not release it in a live session (b2750378, ~8 calls). Go straight to `open-here x-apple.systempreferences:com.apple.Keyboard-Settings.extension` → Keyboard Shortcuts… → Input Sources → untick both → Done; if they already look unticked, tick and untick again. The `defaults write` in stage 14 stays for fresh Macs. It comes back after every Mac restart even with `enabled = 0` for 60/61 in the plist, so the plist proves nothing: go straight to the GUI, no `defaults write`, no plist diagnosis. Root cause unknown (a8b9bde2).

## The lab (`mrglaszki`)

tuios runs on the lab too. From the Mac, `hd-mrglaszki` = `tuios attach --host mrglaszki`:
the local daemon holds an ssh link (`[hosts.mrglaszki]` in the config, `command` points at the
linuxbrew `tuios`), and the lab's session is drawn in a plain Ghostty window with local keys
and theme, nothing nested. Run it **outside** a tuios pane (inside, it refuses). If the link
drops the session keeps running; the client redials for ~3 min. Prerequisites: `ssh mrglaszki`
works non-interactively (`BatchMode`, accept the host key by hand once) and the lab's tuios is new enough to serve the Mac's client (`tuios hosts test mrglaszki`). `tuios ls --all-hosts` lists both machines.
Fallback: `ssh mrglaszki` then `tuios`.

## Community tooling from the herdr days

- picker-plus (`prefix+t`) → built-in pane finder (`prefix+t`, `prefix+/`).
- herdr-pick plugin (`prefix+u/f`) → tuios hints.
- herdr-nvim sidebar → `prefix+e` scratch + `prefix+o` review overlay.
- tokscale dashboard → `prefix+m` popup.
- window-title-sync, herdr-remote, herdr-pr-tracker: not ported (gh-dash covers PRs, Collie the phone).
- `herdr update --handoff` broke `op`/1Password TCC attribution (herdr #808). For tuios,
  upgrade with `brew upgrade tuios` + `hd-restart`; not verified against `op`.
