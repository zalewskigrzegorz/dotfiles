---
paths:
  - "dot_config/tuios/**"
  - "bin/tuios-*"
  - "dot_config/nushell/autoload/tuios.nu"
  - "run_after_34-collie.sh"
---

# tuios config and helper scripts (0.11.1)

## Layout

- Config source: `dot_config/tuios/config.d/readonly_10-dotfiles.toml.tmpl` (live `~/.config/tuios/config.d/10-dotfiles.toml`). `config.toml` is what the settings page writes, tracked as `dot_config/tuios/config.toml`: `chezmoi re-add` it after clicking.
- Launcher helpers in `dot_config/nushell/autoload/tuios.nu`: `os-restart`, `os-stop`, `os-mrglaszki`.
- **The agent sidebar (rail) is the core**: its Inbox lists agents that need you (`needs_input`, `errored`, finished turns); it replaced `claude-agent-presence`. State comes from the `tuios agent-hook claude-code` hooks in `.chezmoitemplates/claude-settings.json`; tuios `[notifications.agent]` is the only notifier (the sound Stop hook is gone).
- `work new/ls/switch/rm/pr` wrap `bin/workctl`, the one branch / PR command that `prefix+shift+g`, `prefix+shift+o`, gh-dash's `w` and lazygit's `w` all open.
- **Collie (stage 34)**: installed standalone; it reads `~/.config/herdr/plugins/config/herdr.collie/.env` before `~/.config/collie`, so `COLLIE_MUX=tuios` goes there; then `collie start`. Pairing: `docs/tuios.md` → "Collie (phone)".

## Traps

- **A tape with `Run` or `Type` fails from any pane**, the `prefix+r` popup included: `run-command is refused for this pane: a pane without the respond grant may not press keys`. A pane can't grant itself `respond` (`admin` doesn't include it); the refusal comes before the first window, and a detached `tape exec` from a popup dies with it, log empty. To start a process in a window: `tuios new-window -s <s> --cwd <dir> --json` + `tuios send-text -s <s> -w <id>` (`bin/tuios-basti`). Tapes stay for demos, recordings, TUI tests.
- **A free prefix key is proven only by `tuios keybinds doctor` after `chezmoi apply`.** `keybinds explain`/`list` called `b`, `u`, `v` free while tuios binds them by default, and `explain` ignores our config (`T` is rename workspace here). Check a key against our config before telling Greg.
- **"N config error" banner, or an error after `brew upgrade tuios` → first `tuios keybinds doctor`.** A new version can take a key our config uses (2026-11-16: `toggle_calm` took `prefix+Z`, zoetrope moved to `prefix+E`). Fix config, `chezmoi apply`, `doctor` again; not `daemon.log`, `config validate` or `strings` first.
- **`tuios list-windows --json` gives `id: null`.** Take ids from `tuios ls --json` (`.[] | select(.name == $s) | (.windows // [])[].id`; a windowless session has `windows: null`). Names come from `tuios get-window <id> --json` (`title`, `workspace`).
- **Text sent into a fresh window before its first prompt is lost.** `tuios wait-for window-output --pattern . --timeout 5000`, then `window-idle --idle 300`, then `send-text`.
- **`[notifications.agent] command` is an `after-agent-state` hook loaded at daemon start only**: reload or `set-config` does nothing until `tuios restart-server`. Mail fires no hook; it plays the `needs_input` cue when `notifications.mail.sound = true`, even with agent sound off. A `set-config` from a pane with a client attached writes `config.toml`: take it back out.
- **Change one key line by its content**, not a pattern over the file: a `sed 's/^key = "prefix+X"$/…/'` loop rewrote every command block's key.
- **A window in a detached session (a `workctl` review) starts at 80x24**, and `tuios set-layout --tiling true` without a client fails. Tile from the window's own script (`bin/tuicr-split`), not global `after-attach` / `after-workspace-switch` hooks (Greg rejected those). `tuios config apply` refuses from a pane.
- **A test step "outside tuios" starts with the keys:** `cmd+N` in Ghostty (the `prefix+r` and `scratch` popups are still inside tuios).
