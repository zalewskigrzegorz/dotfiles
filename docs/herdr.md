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
