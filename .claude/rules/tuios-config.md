---
paths:
  - "dot_config/tuios/**"
  - "bin/tuios-*"
---

# tuios config and helper scripts (0.11.1)

From the `basti` session work (2026-10-28, ~30 calls on the first two):

- **A tape with `Run` or `Type` fails when started from any pane**, the `prefix+r` popup included: `run-command is refused for this pane: a pane without the respond grant may not press keys`. A pane cannot grant itself `respond` (it never gives more than it holds, and `admin` does not include it). The refusal comes before the first window opens, and a detached `tape exec` from a popup dies with the popup, so its log stays empty. To start a process in a window, use `tuios new-window -s <s> --cwd <dir> --json` + `tuios send-text -s <s> -w <id>` (see `bin/tuios-basti`). Tapes stay for demos, recordings and TUI tests.
- **A free prefix key is proven only by `tuios keybinds doctor` after `chezmoi apply`** of the config. `keybinds explain` and `list` called `b`, `u`, `v` free while tuios binds them by default (sidebar, hints, split), and `explain` ignores our config (`T` is rename workspace here, which hides the tape prefix). Before telling Greg a key, check it against our config as well.
- **`tuios list-windows --json` gives `id: null`.** Take window ids from `tuios ls --json` (`.[] | select(.name == $s) | .windows[].id`).
- **Text sent into a fresh window before its first prompt is lost.** Wait with `tuios wait-for window-output --pattern . --timeout 5000`, then `window-idle --idle 300`, then `send-text`.
- **Change one key line by its content, not by a pattern over the file.** A `sed 's/^key = "prefix+X"$/…/'` loop rewrote the key of every command block at once.
