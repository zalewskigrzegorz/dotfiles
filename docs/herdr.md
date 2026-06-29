# herdr — agent multiplexer (tmux+sesh replacement)

[herdr](https://github.com/ogulcancelik/herdr) is a Rust terminal multiplexer with a
native **agent-state sidebar** (priority-sorted: blocked → done → working → idle).
That sidebar is the reason for the switch — it replaces the whole hand-built
`claude-agent-presence` stack. Migration plan + research live in
`~/Code/personal/bazgroly/dotfiles/{plans,analysis}/2026-06-28-herdr-*.md`.

## Status: trial, tmux NOT removed

tmux + sesh stay fully intact as the fallback. Nothing is decommissioned until the
go/no-go test below passes.

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

## Key bindings (defaults kept)

| Key | Action |
|---|---|
| `ctrl+b` | prefix |
| `prefix+?` | help / keys-search (native — replaces keys-search.sh) |
| `prefix+b` | toggle sidebar |
| `prefix+shift+g` | new git worktree (→ grouped workspace) |
| `prefix+g` / `prefix+w` | goto picker / workspace nav |
| `prefix+alt+1..9` | jump to agent N |
| `prefix+h/j/k/l` | focus pane · `prefix+[` copy mode · `prefix+q` detach |

## Peek (replaces tmux-peek)

Native `herdr` agent skill: `herdr pane read <w-p> --source recent --lines 50`,
`herdr agent list`, `herdr agent wait <t> --status done`. Every pane exports
`HERDR_PANE_ID` / `HERDR_WORKSPACE_ID` / `HERDR_SOCKET_PATH`.

## Claude integration (needs explicit approval — self-modifies ~/.claude)

```
herdr integration install claude        # writes ~/.claude/hooks/herdr-agent-state.sh
                                         # + a SessionStart hook in ~/.claude/settings.json
herdr integration status                # integration version must be >= 7
```

Gives session-identity for `--resume` after a server restart (NOT the blocked/idle
state — that's screen-scraped). **chezmoi gotcha:** mirror the added hook block into
`dot_claude/settings.json.tmpl` and the script into `dot_claude/hooks/`, or
`chezmoi apply` reverts it.

## GO / NO-GO test (issue #846) — do this before removing tmux

Open issue [#846](https://github.com/ogulcancelik/herdr/issues/846): unfocused panes may
not re-scan, so a background Claude agent at an approval prompt can stay `idle` instead
of going `blocked`. That defeats the sidebar.

1. `hd`, open two panes, run `claude` in one.
2. Focus the other pane (background the claude one).
3. Let the claude agent hit a tool-approval prompt.
4. **Does the sidebar flip that agent to `blocked` (red) within seconds, unfocused?**
   - Yes → GO. No (stays idle until focused) → NO-GO, stay on tmux.

Also sanity-check while trialling: nvim `Ctrl+/` + mouse drag-select (#847/#693),
F1–F4 in nvim (#818), and never use `herdr update --handoff` — it breaks `op`/1Password
TCC attribution (#808); restart the server instead.
