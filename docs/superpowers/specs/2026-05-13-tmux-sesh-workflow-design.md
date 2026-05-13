# Tmux + Sesh Workflow — Design

**Date:** 2026-05-13
**Status:** Draft, awaiting user review

## Goal

Unify tmux session management across local macOS workstation and remote Linux lab over SSH:

1. SSH into lab → auto-attach to a tmux session (no more lost sessions on disconnect).
2. Same UX locally and remotely: fuzzy session picker via `sesh`.
3. Sessions per project; windows act like Aerospace workspaces (numbered, one app per window, spawned on demand).
4. Window names have nerd-font icons.
5. Persistence across reboots/disconnects via `tmux-continuum` + `tmux-resurrect` (already configured).

## Non-goals

- No predefined pane splits inside windows. User opens splits manually when needed.
- No multi-user / shared sessions.
- No remote dotfiles bootstrap (lab already has full chezmoi setup).

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Local (macOS)                       Lab (Linux 192.168.50.10) │
│                                                                │
│  Ghostty                            ssh greg@lab               │
│    │                                  │                        │
│    ▼                                  ▼                        │
│  nu (login)                         nu (login, SSH_TTY set)    │
│    │                                  │                        │
│    │ ghostty.nu                       │ ssh-tmux.nu            │
│    ▼                                  ▼                        │
│  tmux attach -As ghostty            exec sesh connect          │
│    │                                  │                        │
│    └────── prefix+f ──────► sesh fzf picker                    │
│                                       │                        │
│                                       ▼                        │
│                              new tmux session                  │
│                              (startup_command renames W1)      │
│                                       │                        │
│  user types `nvim`/`claude`/`lazygit` ──► tmux new-window      │
│                                            with icon + name    │
└──────────────────────────────────────────────────────────────┘
```

### Mental model

- **Session = project.** `redocly`, `dotfiles`, `lab` (lokalnie), or anything zoxide picks up.
- **Window 1 = terminal**, always present, named `  term`.
- **Other windows = apps**, spawned on demand by wrappers:
  - `nvim` → window `  nvim`
  - `claude` → window `󰚩  claude`
  - `lazygit` → window `  git`
- Windows numbered 1..N like Aerospace workspaces. Switch with `prefix + 1..9` (tmux default).

---

## Components

### 1. `sesh` (new dependency)

Install via Homebrew on both machines.

**File:** `dot_Brewfile.tmpl`

```ruby
brew "sesh"
```

### 2. Sesh config

**File:** `dot_config/sesh/sesh.toml`

```toml
[default_session]
startup_command = "tmux rename-window '  term'"

# No hardcoded project names — sesh discovers via:
# - active tmux sessions
# - zoxide history (already populated by user's cd-ing)
# - ~/Code/* if explicitly listed (only public ones)

[[session]]
name = "dotfiles"
path = "~/Code/dotfiles"
startup_command = "tmux rename-window '  term'"
```

**Privacy note:** Redocly project is NOT hardcoded. It will appear in the sesh picker via zoxide (since user `cd`s there regularly). Lab project is private and lives only on the lab machine.

### 3. Window-spawning wrappers (nushell)

**File:** `dot_config/nushell/autoload/tmux-window-wrappers.nu`

```nu
# Spawn app in a new tmux window with an explicit nerd-font name.
# Outside tmux: behaves like a normal command.

def --wrapped nvim [...args] {
    if ($env.TMUX? != null) {
        let name = "  nvim"
        ^tmux new-window -n $name -c $env.PWD ^nvim ...$args
        ^tmux set-window-option automatic-rename off
    } else {
        ^nvim ...$args
    }
}

def --wrapped claude [...args] {
    if ($env.TMUX? != null) {
        let name = "󰚩  claude"
        ^tmux new-window -n $name -c $env.PWD ^claude ...$args
        ^tmux set-window-option automatic-rename off
    } else {
        ^claude ...$args
    }
}

def lazygit [] {
    if ($env.TMUX? != null) {
        let name = "  git"
        ^tmux new-window -n $name -c $env.PWD ^lazygit
        ^tmux set-window-option automatic-rename off
    } else {
        ^lazygit
    }
}
```

**Interaction with existing aliases** (`dot_config/nushell/autoload/vim.nu`):

- `alias vim = nvim` → calls our wrapped `nvim` ✓
- `alias vi = nvim` → calls our wrapped `nvim` ✓
- `def v` → uses `nvim $in` internally → wrapped ✓

No changes needed in `vim.nu`.

**Why disable `automatic-rename` per window:** The existing `tmux-nerd-font-window-name` plugin renames windows automatically based on process detection. It does not know `claude` (too new) and may overwrite our explicit names. Setting `automatic-rename off` on each spawned window pins our name + icon.

### 4. SSH auto-sesh on lab

**File:** `dot_config/nushell/autoload/ssh-tmux.nu`

```nu
# When logging in via SSH and not already in tmux, open the sesh picker.
# Local Ghostty is handled by ghostty.nu (already exists).

if ($env.SSH_CONNECTION? != null) and ($env.TMUX? == null) and ($env.SSH_TTY? != null) {
    exec sesh connect
}
```

`exec` replaces the nu process so when the user detaches from tmux, the SSH session ends. To detach without closing SSH, the user can use `prefix + d`.

### 5. SSH config alias

**File:** `dot_ssh/private_config.tmpl` (chezmoi-managed, not in public repo)

```
Host lab
    HostName 192.168.50.10
    User greg
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Chezmoi will place this at `~/.ssh/config` on macOS. The `private_` prefix ensures restricted permissions (chmod 600).

**Existing `~/.ssh/config` migration:** A file already exists at `~/.ssh/config` (not chezmoi-managed). Before `chezmoi apply`, manually back it up (`cp ~/.ssh/config ~/.ssh/config.bak`) and copy any non-`lab` host entries into the new templated file. Chezmoi will refuse to overwrite without this step.

### 6. Tmux keybind for sesh picker

**File:** `dot_config/tmux/tmux.conf` — add near other keybinds:

```tmux
# Sesh: fuzzy session picker
bind-key "f" run-shell "sesh connect \"$(sesh list -i | fzf-tmux -p 55%,60% --no-sort --ansi)\""
```

Prefix is already `Space`, so this becomes `Space f`.

### 7. Continuum / Resurrect tuning

Currently:

```tmux
set -g @resurrect-dir '~/.local/share/tmux/resurrect'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
```

**Changes:**

- Lower save interval to `5` (every 5 minutes) so disconnect-loss is smaller.
- Add `@resurrect-capture-pane-contents 'on'` so pane scrollback survives.
- Add `@resurrect-processes` allowlist so `nvim`, `claude`, `lazygit` are restarted on restore.

```tmux
set -g @continuum-save-interval '5'
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-processes 'nvim claude lazygit'
```

### 8. Plugin install hook

`run_once_after_45-install-tmux-plugins.sh` already exists — should auto-install plugins on chezmoi apply.

---

## Diagnostic step: "tmux session disappears when Ghostty closes"

Before changing anything, verify the actual behavior:

1. Open Ghostty → in `ghostty` session → run `echo $$ > /tmp/test-tmux-pid`.
2. Quit Ghostty (`cmd+q`).
3. From another terminal (iTerm fallback or `ssh localhost`), run `pgrep -lf tmux`.

**Expected:** tmux server still running. Session `ghostty` still exists. Reopening Ghostty re-attaches.

**If server dies:**

- Likely cause: Ghostty's `quit-after-last-window-closed = true` combined with `exec tmux` keeping tmux in the same process group → SIGHUP cascade.
- **Fix:** detach via daemon — replace `exec tmux ...` in `ghostty.nu` with:

  ```nu
  # Start server if missing; then attach in foreground (server stays after detach)
  ^tmux start-server
  exec tmux new-session -A -s ghostty
  ```

  (or use `tmux -L socket-name` to ensure a stable socket).

**If session is there but pane contents fresh:**

- Resurrect saves layout + cwd, not running processes by default.
- Already handled in step 7 (capture-pane-contents + processes allowlist).

This diagnosis is a checkpoint in the implementation plan, not a guess.

---

## Data flow examples

### Example 1 — local, fresh start

1. User opens Ghostty.
2. `ghostty.nu` autoload: not in tmux → `exec tmux new-session -A -s ghostty`.
3. Tmux server starts (or attaches existing). `continuum-restore on` restores last saved state.
4. User hits `prefix + f` → sesh picker fzf.
5. User picks `redocly` (from zoxide). New session created in `~/Code/redocly`.
6. `default_session.startup_command` runs: renames W1 to `  term`.
7. User types `claude` → wrapper spawns W2 `󰚩  claude`.

### Example 2 — SSH into lab

1. User runs `ssh lab` (alias from `~/.ssh/config`).
2. nu logs in, `ssh-tmux.nu` fires: `SSH_CONNECTION` set, `TMUX` unset → `exec sesh connect`.
3. Sesh picker shows existing tmux sessions (or empty).
4. User picks `lab` → attaches to existing session (or creates new with renamed W1).
5. Continuum had been saving every 5 min on the lab side → state restored.
6. User disconnects (`prefix + d` or just kills ssh) → tmux server on lab keeps running.

---

## Files inventory

### Created

- `dot_config/sesh/sesh.toml`
- `dot_config/nushell/autoload/tmux-window-wrappers.nu`
- `dot_config/nushell/autoload/ssh-tmux.nu`
- `dot_ssh/private_config.tmpl`
- `docs/superpowers/specs/2026-05-13-tmux-sesh-workflow-design.md` (this file)

### Modified

- `dot_Brewfile.tmpl` — add `brew "sesh"`
- `dot_config/tmux/tmux.conf` — add `prefix+f` keybind + resurrect tuning
- `dot_config/nushell/autoload/ghostty.nu` — possibly switch to `tmux start-server` + attach (depends on diagnostic)

### Untouched

- `dot_config/nushell/autoload/vim.nu` — existing aliases coexist with wrappers
- `dot_config/nushell/autoload/tmux.nu` — existing `ta`, `tl`, `tn`, `tk` helpers unchanged
- `dot_config/tmux/tmux-nerd-font-window-name.yml` — plugin still active for sessions where automatic-rename remains on (e.g. unknown commands)

---

## Validation checklist

- [ ] `brew install sesh` works on both machines (linuxbrew on lab, homebrew on Mac).
- [ ] `sesh list` shows expected projects on each machine.
- [ ] `ssh lab` lands directly in sesh picker.
- [ ] Disconnecting SSH (close terminal) leaves tmux server alive on lab (verify with `ssh lab pgrep -lf tmux`).
- [ ] `claude` / `nvim` / `lazygit` typed in W1 spawn correctly named/iconed windows.
- [ ] `automatic-rename` does NOT overwrite explicit names.
- [ ] Existing `vim`/`vi`/`v` aliases still work.
- [ ] Reboot of Mac: Ghostty reopens, attaches to `ghostty`, previous sessions restored by continuum.
- [ ] `redocly` does not appear in any committed dotfile.

---

## Open risks / decisions

- **Lab Linux package source:** lab uses `linuxbrew` (per existing env.nu.tmpl). `brew "sesh"` in Brewfile works there too. ✓
- **fzf-tmux on lab:** must be installed. Verify in implementation step.
- **`sesh connect` UX inside SSH:** if user prefers to skip picker and always land on `main`, swap `exec sesh connect` for `exec tmux new-session -A -s main` in `ssh-tmux.nu`. Currently picker is preferred per user.
- **Migration:** existing `ghostty` session on Mac may be reset when applying the new resurrect config. Lossy if user has untracked work — recommend saving manually before `chezmoi apply`.
