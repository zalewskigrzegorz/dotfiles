# herdr — agent multiplexer (tmux+sesh replacement)

[herdr](https://github.com/ogulcancelik/herdr) is a Rust terminal multiplexer with a
native **agent-state sidebar** (priority-sorted: blocked → done → working → idle).
That sidebar is the reason for the switch — it replaces the whole hand-built
`claude-agent-presence` stack. Migration plan + research live in
`~/Code/personal/bazgroly/dotfiles/{plans,analysis}/2026-06-28-herdr-*.md`.

## Status: migrated to herdr

herdr is the active multiplexer on the Mac. `claude-agent-presence` (sketchybar chip,
`bin/claude-agent-*`, `tmux-window-jump`) and the whole sesh family (`bin/sesh*`,
`sesh.nu`, `dot_config/sesh`, `claude-focus-session`) are **decommissioned**. url/file
opening is now the `url` and `of` nu commands (`autoload/herdr-pick.nu`), not pluck.

tmux is kept as a **cold backup only** — `dot_config/tmux/tmux.conf`, `brew "tmux"`, TPM,
and the statusline scripts feeding tmux.conf stay in place but are not active.

- **Backup point:** `git tag pre-herdr` and branch `pre-herdr-backup`.
- **Revert:** `git -C ~/Code/dotfiles checkout pre-herdr` (tmux config never changed).

## Install + config

- `brew "herdr"` in `dot_Brewfile.tmpl` (Mac + lab).
- Config: `dot_config/herdr/config.toml` → `~/.config/herdr/config.toml`.
  - nu shell, catppuccin + Mocha Neon `[theme.custom]` overrides.
  - `[ui] agent_panel_sort = "priority"`, `[session] resume_agents_on_restore = true`.
  - Regenerate the default for reference: `herdr --default-config`.
  - **Lab TODO:** `default_shell` is the Mac nu path — templatize per-OS before lab rollout.
- Launcher aliases: `dot_config/nushell/autoload/herdr.nu` → `hd`, `hd-restart`, `hd-stop`.
- Worktree workflow via the herdr-native `work` CLI: `new` / `ls` / `switch` / `rm` / `pr`.

## Key bindings (defaults kept)

| Key | Action |
|---|---|
| `ctrl+space` | prefix |
| `prefix+?` | help / keys-search (native — replaces keys-search.sh) |
| `prefix+b` | toggle sidebar |
| `prefix+w` / `prefix+g` | workspace picker / goto |
| `prefix+a` | agent cycle · `prefix+0` jump to waiting agent |
| `prefix+h/j/k/l` | focus pane · `prefix+[` copy mode · `prefix+q` detach |
| `prefix+u` / `prefix+f` | pick URL → browser / file → nvim (our `greg.herdr-pick` plugin) |
| `prefix+t` | picker-plus: workspaces / ssh / zoxide / agent panes |
| `prefix+r` | reviewr code-review sidebar · `prefix+m` tokscale usage |

## Peek (replaces tmux-peek)

Native `herdr` agent skill: `herdr pane read <w-p> --source recent --lines 50`,
`herdr agent list`, `herdr agent wait <t> --status done`. Every pane exports
`HERDR_PANE_ID` / `HERDR_WORKSPACE_ID` / `HERDR_SOCKET_PATH`.

## Claude integration (needs explicit approval — self-modifies ~/.claude)

```
herdr integration install claude        # writes ~/.claude/hooks/herdr-agent-state.sh
                                         # + a SessionStart hook in ~/.claude/settings.json
herdr integration status                # integration version must be >= 7 (v7 in use)
```

Gives session-identity for `--resume` after a server restart (NOT the blocked/idle
state — that's screen-scraped). **chezmoi gotcha:** mirror the added hook block into
`dot_claude/settings.json.tmpl` and the script into `dot_claude/hooks/`, or
`chezmoi apply` reverts it.

## GO / NO-GO test (issue #846) — RESULT: GO

The go/no-go gate was whether [#846](https://github.com/ogulcancelik/herdr/issues/846)
(unfocused panes may not re-scan, so a background Claude agent at an approval prompt
stays `idle` instead of going `blocked`) defeats the sidebar in practice.

**Result: GO.** Greg confirmed agent state updates fine — a background, unfocused
blocked agent flips to `blocked` (red) in the sidebar within seconds. Migration adopted.

Also sanity-check while trialling: nvim `Ctrl+/` + mouse drag-select (#847/#693),
F1–F4 in nvim (#818), and never use `herdr update --handoff` — it breaks `op`/1Password
TCC attribution (#808); restart the server instead.

## Tab / window naming (our own)

- **In-herdr tab labels** are ours:
  - `work` names the worktree's tabs (claude tab `󰚩 claude`, shell tab ` nu`).
  - `zz-herdr-tui-wrappers.nu` — running `lg`/`dash`/`nvim`/`lazydocker`/`btop`/`hunk`
    renames the *current* tab to a nerd-font icon while the TUI runs, restoring the
    previous label on exit. Port of the old tmux window wrappers.
  - `dot_claude/hooks/stop/herdr-claude-title.sh` (Stop hook) — renames the claude tab
    to `󰚩 <topic>`, reading the latest `aiTitle` from the transcript.

## Our own plugin: greg.herdr-pick (url / file picker)

`prefix+u` / `prefix+f` open a native picker overlay that scans **every** pane's
scrollback, fzf-picks a URL → browser (`ctrl-y` copies) or a file → nvim in a new tab.
Pure nu (reuses the regex from `autoload/herdr-pick.nu`), no Go build. Source lives in
the repo at `dot_config/herdr/plugins-src/herdr-pick/` (chezmoi renders it to
`~/.config/herdr/plugins-src/`), and `run_34` `herdr plugin link`s it. Replaces the
old tmux fzf-url-picker (`prefix u`) + open-file-window (`prefix F/H/G`) and supersedes
the community `herdr-fzf-url` (which is URL-only and needs a Go build).

## Community tooling — adopted

Installed via `run_onchange_after_34-herdr-plugins-sync.sh` (Mac; lab still tmux):

- **[thanhdat77/herdr-picker-plus](https://github.com/thanhdat77/herdr-picker-plus)** —
  `prefix+t`. Unified fuzzy picker: workspaces / SSH hosts / zoxide / agent panes / roots
  / quick actions. Pure Rust TUI (no fzf/Bun dep; cargo build at install). The Dygma-button
  candidate. Plugin config (`herdr plugin config-dir herdr-picker-plus`) defaults roots to
  `~/workspace`/`~/projects` — repoint at `~/Code` if you want the roots source useful.
- **[rjyo/herdr-window-title-sync](https://github.com/rjyo/herdr-window-title-sync)** —
  no keybind, event-driven. Sets the **OS window title** (Ghostty/Moshi) from agent status
  / recent prompt via `herdr terminal title set`. Needs **bun** (`brew "oven-sh/bun/bun"`).
  Different target from our `herdr-claude-title.sh` hook (which renames the in-herdr *tab*).
- **[astkaasa/herdr-tokscale-dashboard](https://github.com/astkaasa/herdr-tokscale-dashboard)** —
  `prefix+m` (`y` reads as yank; `t` taken by picker-plus). Opens the Tokscale token-usage +
  cost TUI as a pane. Needs Tokscale; we don't install a binary, so `run_34` writes
  `TOKSCALE_CMD="bunx tokscale@latest"` into the plugin config (first run is slow — bunx cold
  start). Don't bind the `pulse-json` action (stale — `tokscale pulse` doesn't exist). Low
  maturity (~2 commits) — watch.

## Community tooling — parked

- **[dcolinmorgan/herdr-remote](https://github.com/dcolinmorgan/herdr-remote)** +
  `herdr-push` — approve blocked agents from phone / menubar / Telegram, **no SSH**. Not a
  plain `plugin install`: a Python WebSocket relay (~300 lines) + the push plugin per host.
  Plan: relay on the **lab** polling the Mac's herdr over SSH, PWA on the phone (~15 min LAN;
  WSS-vs-WS is the one catch — Tailscale cleanest). Full step-by-step:
  `~/Code/personal/bazgroly/dotfiles/plans/2026-06-29-herdr-remote-lab-deploy.md`. Greg runs
  it on the lab himself.
- **[x0d7x/herdr-fzf-url](https://github.com/x0d7x/herdr-fzf-url)** — superseded by our
  `greg.herdr-pick` plugin (above), which does URL **and** file in pure nu without a Go build.
- **[Matovidlo/herdr-pr-tracker](https://github.com/Matovidlo/herdr-pr-tracker)** —
  **tried and dropped (2026-06-29).** Its `open-board` action uses the old positional CLI
  herdr 0.7.1 rejects, `prefix+shift+p` collides with the built-in `rename_pane`, the board
  TUI lagged on keypress, and every row showed `(no PR)` unless a session sits on a branch
  with an open PR. `gh-dash` covers PR review/merge far better — use that.
