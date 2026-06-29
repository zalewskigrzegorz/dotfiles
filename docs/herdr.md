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

## Community tooling (to evaluate)

Two community projects overlap with the above — worth wiring in, not yet adopted:

- **[rjyo/herdr-window-title-sync](https://github.com/rjyo/herdr-window-title-sync)** —
  herdr plugin (`herdr plugin install rjyo/herdr-window-title-sync`, needs Bun, 0.7.0+).
  Sets the **OS terminal window title** (OSC) from pane metadata → agent status → recent
  Claude/Codex prompt → tab name. **Different target** from our hook: we rename the
  *in-herdr tab label*, this sets the *Ghostty/Moshi window title*. Complementary —
  adopting it gives a useful title in the phone/Moshi view without touching our tab logic.
- **[dcolinmorgan/herdr-remote](https://github.com/dcolinmorgan/herdr-remote)** —
  standalone relay: **approve blocked agents from phone / menubar / Telegram, no SSH**.
  Companion plugin `herdr plugin install dcolinmorgan/herdr-push` on each herdr host +
  a WebSocket relay server. Covers the parked ntfy / "Tina notification router" idea and
  the "jump to waiting agent" need from the away-from-keyboard side. Real infra to stand
  up (relay server), so deferred like ntfy until decided.

- **[thanhdat77/herdr-picker-plus](https://github.com/thanhdat77/herdr-picker-plus)** —
  herdr plugin (`herdr plugin install thanhdat77/herdr-picker-plus --yes`). One key
  opens a unified fuzzy picker over: open workspaces (reuses, no dupes), project
  templates, SSH hosts, zoxide dirs, agent panes, quick actions, plugin integrations.
  **Most wire-ready of the three** — plugin install + one keybind, no Bun, no relay.
  Good candidate for a single Dygma button. Config:
  ```toml
  [[keys.command]]
  key = "prefix+t"
  type = "plugin_action"
  command = "herdr-picker-plus.open"
  ```

- **[x0d7x/herdr-fzf-url](https://github.com/x0d7x/herdr-fzf-url)** — herdr plugin
  (`herdr plugin install x0d7x/herdr-fzf-url`, Go build). Scans pane scrollback for
  URLs → fzf → Enter opens / `y` copies. **We already have the core** as `url` in
  `herdr-pick.nu` (current pane → fzf → `open`). Plugin adds: multi-pane scan,
  clipboard copy, and a native keybind. Its default `alt+u` won't work here (alt is
  reserved for Polish diacritics) — pick a `prefix+…` chord if adopted.

If adopted, the installable plugins (`herdr-window-title-sync`, `herdr-push`,
`herdr-picker-plus`, `herdr-fzf-url`) go into
`run_onchange_after_34-herdr-plugins-sync.sh`; the relay server is separate infra.
