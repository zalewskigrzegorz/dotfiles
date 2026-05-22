# Spec: Interactive tmux keybindings search (`prefix + ?`)

**Status**: implemented, awaiting commit
**Repo**: `~/Code/dotfiles` (personal — spec lives in-repo per CLAUDE.md rules)
**Date**: 2026-05-22

## Context

Tmux config has grown to ~30+ custom prefix bindings plus the default ones, plugin bindings (tmux-fzf-url, tmux-fzf-open-files-nvim, tmux-menus, sesh launcher, navi launcher, vim-tmux-navigator, etc.) and the copy-mode tables. Holding the full set in memory is unrealistic.

Previously this was supposed to be solved by **navi** (`prefix + b`). It failed for two reasons:

1. **Forgotten** — the launcher itself sits behind a binding the user forgets.
2. **Not maintained** — navi cheatsheets are flat files. Adding a tmux binding to `tmux.conf` does not update navi. The cheatsheet drifts from reality and gets ignored.

Default tmux `prefix + ?` runs `list-keys -N` — a static, paged, non-searchable dump. Useless for "I know it had 'url' in the name, what was the key?" lookups.

## Goal

Replace `prefix + ?` with an **interactive, searchable popup over `tmux list-keys`** so the user can fuzzy-find any binding by key, table, or command. Source of truth is the running tmux server — no flat-file cheatsheet to maintain.

## Non-goals

- **No execution on Enter.** The popup is a cheatsheet, not a launcher palette. Avoids edge cases with copy-mode-only commands, prefix chord re-triggering, and binding arguments that open their own popups.
- **No per-binding descriptions.** `bind-key -N "..."` exists but adding/maintaining descriptions for every binding is exactly the maintenance burden that killed navi.
- **No filtering of "noisy" tables.** copy-mode bindings stay in the list; user can fzf-narrow if they want.

## Decisions

| Decision | Choice | Why |
|---|---|---|
| Enter behavior | dismiss only | matches "cheatsheet" mental model, zero edge cases |
| Tables shown | all (`prefix`, `root`, `copy-mode`, `copy-mode-vi`) | full coverage, fzf handles the noise |
| Popup engine | `fzf-tmux` (own popup) | proven in `fzf-url-picker.sh` + `open-file-window.sh`; `tmux display-popup -E` had quoting issues under `run-shell` |
| Sort | `--no-sort` | preserve tmux's natural ordering |
| Tiebreak | `--tiebreak=begin` | favor matches at token start (search "u" → `prefix u` before copy-mode bindings containing "u") |
| Popup size | 90% × 80% | wide enough for long `run-shell` commands without wrap |

## Architecture

Three pieces, all matching the existing dotfiles pattern:

```
dot_config/tmux/
├── executable_keys-search.sh   # NEW — the popup script
├── executable_open-file-window.sh
├── executable_fzf-url-picker.sh
└── tmux.conf                   # MODIFIED — adds prefix+? override
```

### Component 1: `executable_keys-search.sh`

Single-purpose script. ~15 lines bash:

```bash
#!/usr/bin/env bash
set -euo pipefail

tmux list-keys \
  | sed -E 's/^bind-key +-(r|N) +/bind-key  /; s/^bind-key +-T +([^ ]+) +/\1\t/' \
  | fzf-tmux -p 90%,80% \
      --prompt='tmux key> ' \
      --header='prefix+? — search bindings (Esc to dismiss)' \
      --no-sort \
      --tiebreak=begin \
      --delimiter='\t' \
  || true
```

- `set -euo pipefail` — fail loud on parse errors
- `|| true` — fzf-tmux exits 130 on Esc; that is the **expected** cancel path, not an error

### Component 2: `tmux.conf` binding

Placed **after** `run '~/.config/tmux/plugins/tpm/tpm'` so TPM cannot clobber the override. Same pattern as the existing `prefix + u`, `F`, `H`, `G` overrides:

```
unbind-key -T prefix ?
bind-key -T prefix ? run-shell 'bash -lc "~/.config/tmux/keys-search.sh"'
```

### Component 3: format transformation

`tmux list-keys` output:

```
bind-key    -T prefix             u                          run-shell -b "bash -lc ..."
bind-key    -r -T prefix          H                          resize-pane -L 5
```

After `sed`:

```
prefix	u                          run-shell -b "bash -lc ..."
prefix	H                          resize-pane -L 5
```

The tab makes `<table>` a separate searchable token in fzf (via `--delimiter='\t'`). Visually columns aren't aligned (no `column -t`) but fzf rendering keeps each row readable.

## Data flow

```
prefix+? ─▶ run-shell
              │
              ▼
   bash -lc keys-search.sh
              │
              ▼
   tmux list-keys (full server state)
              │
              ▼
   sed reformat: "bind-key -T <t>" → "<t>\t"
              │
              ▼
   fzf-tmux popup (90%×80%, --no-sort, --tiebreak=begin)
              │
              ▼
   user types to filter / Esc to dismiss
              │
              ▼
   script exits (selection ignored)
```

## Error handling

- `set -euo pipefail` catches unexpected parse failures.
- `|| true` on the fzf-tmux pipeline catches the expected cancel-exit (130).
- If invoked outside a tmux session (e.g., user runs the script by hand without tmux): `tmux list-keys` errors → script exits non-zero → no popup. Acceptable since the script is binding-only.
- If `fzf-tmux` is missing: script exits with command-not-found. Brewfile already pins `fzf`, which ships `fzf-tmux`.

## Testing

Manual smoke test from inside an active tmux session:

1. `prefix + ?` → popup opens with ~200 lines
2. Type `url` → `prefix u  run-shell -b ".../fzf-url-picker.sh"` appears
3. Type `nvim` → `prefix F/H/G  run-shell ".../open-file-window.sh"` appears
4. Type `sesh` → `prefix f  run-shell "sesh connect ..."` appears
5. Esc → popup closes, no side effects
6. Add a new binding to `tmux.conf`, reload (`prefix + r`), `prefix + ?` → new binding visible immediately

No unit tests — the script is glue between `tmux list-keys`, `sed`, and `fzf-tmux`. Each dependency is independently testable upstream.

## Maintenance footprint

**Zero.**

- Adding a binding in `tmux.conf` → next `prefix + ?` shows it automatically.
- Removing a binding → disappears from popup on next invocation.
- New plugin installed via TPM with its own bindings → visible without touching this script.

No cheatsheet markdown to keep in sync, no yaml aliases, no Raycast script command, no Navi snippets. This is the entire point.

## Related work (future, out of scope)

The same pattern — runtime introspection + fzf-tmux popup — replicates trivially in other tools:

| Tool | Source | Binding idea |
|---|---|---|
| nvim | `:Telescope keymaps` (or which-key.nvim) | `<Leader>?` |
| Aerospace | `aerospace list-modes --json` | popup via shortcut in `aerospace.toml` |
| nushell | `keybindings list` | alias `?keys` piped through fzf |
| Ghostty | parse config file | one-off script + Raycast Quicklink |

Each gets its own spec when it's worth doing. A central aggregator (Raycast Cheatsheet, single markdown, etc.) is **explicitly rejected** — it reintroduces the maintenance burden that killed navi.

The only legitimate central artifact: a tiny "meta-bindings" cheatsheet for top-level inter-tool launchers (tmux prefix key, Aerospace workspace shortcuts, Raycast hotkey). ~10-15 lines, changes once a year. Not in scope for this spec.

## Files changed

- `dot_config/tmux/executable_keys-search.sh` (new, executable via chezmoi naming)
- `dot_config/tmux/tmux.conf` (added `unbind-key`/`bind-key` block for `prefix + ?` under the existing post-TPM override section)

## Acceptance

Spec accepted once user can press `prefix + ?` from any pane and search across all tmux bindings with sub-200ms popup open time.
