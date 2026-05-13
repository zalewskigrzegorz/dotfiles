# Tmux + Sesh Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify tmux session management across Mac and SSH lab with sesh fuzzy picker, sessions-as-projects, Aerospace-style numbered windows spawned by nushell wrappers, and persistent state across disconnects.

**Architecture:** Install sesh on both machines. Configure default_session startup to rename W1 with an icon. Wrappers in `tmux-window-wrappers.nu` intercept `nvim`/`claude`/`lazygit` calls and spawn new tmux windows with explicit nerd-font names + `automatic-rename off`. SSH auto-attaches via `ssh-tmux.nu` autoload. SSH config alias `lab` points at `192.168.50.10`. Tmux-continuum interval lowered and process allowlist expanded.

**Tech Stack:** chezmoi (dotfiles templating), Homebrew/linuxbrew (sesh install), tmux 3.x with TPM, nushell 0.x autoload, fzf-tmux.

**Repo conventions:**
- Edit files under `~/Code/dotfiles/dot_config/...` then run `chezmoi apply` to materialize at `~/.config/...`.
- Commit directly to master (per user preference, this is a personal repo).
- Pre-commit gitleaks hook scans for secrets. No `redocly` in tracked files.

**Spec reference:** `docs/superpowers/specs/2026-05-13-tmux-sesh-workflow-design.md`

---

## File Structure

### Created
- `dot_config/sesh/sesh.toml` — sesh config with default_session startup
- `dot_config/nushell/autoload/tmux-window-wrappers.nu` — wrappers for nvim/claude/lazygit
- `dot_config/nushell/autoload/ssh-tmux.nu` — SSH auto-attach to sesh
- `private_dot_ssh/config.tmpl` — chezmoi-managed SSH config

### Modified
- `dot_Brewfile.tmpl` — add `brew "sesh"`
- `dot_config/tmux/tmux.conf` — `prefix+f` keybind + resurrect tuning
- `dot_config/nushell/autoload/ghostty.nu` — possibly switch to `tmux start-server` (decided by Task 1 diagnostic)

### Untouched
- `dot_config/nushell/autoload/vim.nu`
- `dot_config/nushell/autoload/tmux.nu`
- `dot_config/tmux/tmux-nerd-font-window-name.yml`

---

## Task 1: Diagnostic baseline — does tmux server survive Ghostty quit?

**Files:** none modified, observation only

**Why first:** Determines whether Task 8 (Ghostty autostart change) is needed.

- [ ] **Step 1: Open a fresh Ghostty window**

Use a new Ghostty window. The autoload `ghostty.nu` will run `exec tmux new-session -A -s ghostty`.

- [ ] **Step 2: Record server PID**

In the tmux pane:

```nu
^tmux display-message -p '#{pid}' | save -f /tmp/diag-tmux-pid.txt
cat /tmp/diag-tmux-pid.txt
```

Expected: a numeric PID printed.

- [ ] **Step 3: Quit Ghostty (`Cmd+Q`)**

Close the Ghostty app entirely.

- [ ] **Step 4: From another terminal, check the server**

Open iTerm or any non-Ghostty terminal (Terminal.app), then:

```bash
pgrep -lf "tmux: server" || echo "NO SERVER"
cat /tmp/diag-tmux-pid.txt
```

Expected (case A): same PID printed → tmux server survived → Task 8 = skip.
Expected (case B): "NO SERVER" → tmux died with Ghostty → Task 8 = apply fix.

- [ ] **Step 5: Record the outcome**

Edit this plan file: replace the "_record here: ..._" placeholder under Task 7 with "case A" or "case B".

- [ ] **Step 6: Cleanup**

```bash
rm /tmp/diag-tmux-pid.txt
```

No commit yet (no files changed).

---

## Task 2: Add sesh to Brewfile and install locally

**Files:**
- Modify: `dot_Brewfile.tmpl`

- [ ] **Step 1: Find the right section in Brewfile**

Run:

```bash
grep -n "^brew " /Users/greg/Code/dotfiles/dot_Brewfile.tmpl | head -20
```

Look for an alphabetically appropriate spot (between `r*` and `t*` packages).

- [ ] **Step 2: Add the sesh line**

Use Edit to insert `brew "sesh"` in alphabetical order. Example anchor: a line beginning with `brew "starship"` — add the new line directly before it.

- [ ] **Step 3: Apply Brewfile changes**

```nu
chezmoi apply
brew bundle --file=~/.Brewfile
```

Expected: `Installing sesh` output, no errors. If brew bundle is wired into a chezmoi hook, `chezmoi apply` alone may suffice.

- [ ] **Step 4: Verify sesh is installed**

```bash
which sesh && sesh --version
```

Expected: path under `/opt/homebrew/bin/sesh`, version string printed.

- [ ] **Step 5: Commit**

```bash
git add dot_Brewfile.tmpl
git commit -m "feat(brew): add sesh for tmux session management"
```

---

## Task 3: Create sesh.toml

**Files:**
- Create: `dot_config/sesh/sesh.toml`

- [ ] **Step 1: Make the directory**

```bash
mkdir -p /Users/greg/Code/dotfiles/dot_config/sesh
```

- [ ] **Step 2: Write the config**

Create `/Users/greg/Code/dotfiles/dot_config/sesh/sesh.toml` with:

```toml
# Sesh: fuzzy tmux session manager
# https://github.com/joshmedeski/sesh

[default_session]
startup_command = "tmux rename-window '  term'"

# Public, non-secret project
[[session]]
name = "dotfiles"
path = "~/Code/dotfiles"
startup_command = "tmux rename-window '  term'"

# NOTE: Other projects (e.g. redocly) are discovered dynamically via
# zoxide history. Do not hardcode private project names here.
```

- [ ] **Step 3: Apply chezmoi**

```nu
chezmoi apply
```

Expected: file appears at `~/.config/sesh/sesh.toml`.

- [ ] **Step 4: Verify sesh picks it up**

```bash
sesh list
```

Expected: at minimum `dotfiles` listed, plus any active tmux sessions and zoxide entries.

- [ ] **Step 5: Commit**

```bash
git add dot_config/sesh/sesh.toml
git commit -m "feat(sesh): add sesh.toml with dotfiles project and default startup"
```

---

## Task 4: Add `prefix+f` keybind to tmux.conf

**Files:**
- Modify: `dot_config/tmux/tmux.conf`

- [ ] **Step 1: Locate the insertion point**

Open `/Users/greg/Code/dotfiles/dot_config/tmux/tmux.conf` and find the line ending the navigation/binding section (after the vim-like pane keys around line 119). The new bind goes there with a comment.

- [ ] **Step 2: Add the keybind**

Insert these lines after the resize-pane block (around line 119):

```tmux
# Sesh: fuzzy session picker (prefix + f)
bind-key "f" run-shell "sesh connect \"$(sesh list -i | fzf-tmux -p 55%,60% --no-sort --ansi)\""
```

- [ ] **Step 3: Apply chezmoi**

```nu
chezmoi apply
```

- [ ] **Step 4: Reload tmux config in a running tmux**

Inside tmux, hit `prefix r` (already bound in your config to reload). Expect message: `🦄 XDG tmux.conf reloaded!`.

- [ ] **Step 5: Test the keybind manually**

Hit `Space f`. Expected: `fzf-tmux` popup with session list. Pick one or cancel with `Esc`.

- [ ] **Step 6: Commit**

```bash
git add dot_config/tmux/tmux.conf
git commit -m "feat(tmux): bind prefix+f to sesh fuzzy session picker"
```

---

## Task 5: Create tmux-window-wrappers.nu

**Files:**
- Create: `dot_config/nushell/autoload/tmux-window-wrappers.nu`

- [ ] **Step 1: Write the file**

Create `/Users/greg/Code/dotfiles/dot_config/nushell/autoload/tmux-window-wrappers.nu` with:

```nu
# Tmux window wrappers
# When running inside tmux, intercept nvim/claude/lazygit and spawn
# a new tmux window with an explicit nerd-font name. Outside tmux,
# pass through to the underlying binary.
#
# automatic-rename is disabled per spawned window so the nerd-font
# plugin does not overwrite our pinned name.

def --wrapped nvim [...args] {
    if ($env.TMUX? != null) {
        let name = "  nvim"
        ^tmux new-window -n $name -c $env.PWD nvim ...$args
        ^tmux set-window-option automatic-rename off
    } else {
        ^nvim ...$args
    }
}

def --wrapped claude [...args] {
    if ($env.TMUX? != null) {
        let name = "󰚩  claude"
        ^tmux new-window -n $name -c $env.PWD claude ...$args
        ^tmux set-window-option automatic-rename off
    } else {
        ^claude ...$args
    }
}

def lazygit [] {
    if ($env.TMUX? != null) {
        let name = "  git"
        ^tmux new-window -n $name -c $env.PWD lazygit
        ^tmux set-window-option automatic-rename off
    } else {
        ^lazygit
    }
}
```

- [ ] **Step 2: Apply chezmoi**

```nu
chezmoi apply
```

- [ ] **Step 3: Reload nushell in a new tmux pane**

Open a fresh nushell pane (`prefix - ` for vertical split or new window). Old nushell shells won't reload autoloads.

- [ ] **Step 4: Verify wrappers exist**

In the new pane:

```nu
help commands | where name == "claude" | get module_name
```

Expected: prints a module name (autoload sources autoload as a module). If empty, autoload didn't pick up — check file is in `~/.config/nushell/autoload/`.

- [ ] **Step 5: Test claude wrapper**

In a fresh tmux pane:

```nu
claude --help
```

Expected: a new tmux window opens, named `󰚩  claude`, runs `claude --help`. Switch with `prefix p` back to original window.

- [ ] **Step 6: Test nvim wrapper**

```nu
nvim /tmp/test.txt
```

Expected: new window `  nvim`, nvim opened on `/tmp/test.txt`. Quit nvim with `:q`.

- [ ] **Step 7: Test lazygit wrapper**

In a directory that is a git repo:

```nu
cd ~/Code/dotfiles
lazygit
```

Expected: new window `  git` running lazygit on dotfiles repo. Quit with `q`.

- [ ] **Step 8: Verify automatic-rename stays off**

After spawning a window via wrapper, in tmux:

```bash
tmux show-window-options -v automatic-rename
```

Expected: `off`.

- [ ] **Step 9: Commit**

```bash
git add dot_config/nushell/autoload/tmux-window-wrappers.nu
git commit -m "feat(nu): add tmux window wrappers for nvim/claude/lazygit with nerd-font names"
```

---

## Task 6: Tune resurrect + continuum

**Files:**
- Modify: `dot_config/tmux/tmux.conf`

- [ ] **Step 1: Locate the resurrect/continuum section**

Find lines 86-89 in `tmux.conf`:

```tmux
set -g @resurrect-dir '~/.local/share/tmux/resurrect'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
```

- [ ] **Step 2: Update to:**

```tmux
set -g @resurrect-dir '~/.local/share/tmux/resurrect'
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-processes 'nvim claude lazygit'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '5'
```

- [ ] **Step 3: Apply chezmoi**

```nu
chezmoi apply
```

- [ ] **Step 4: Reload tmux config**

`prefix r` inside tmux.

- [ ] **Step 5: Force a save**

```bash
tmux run-shell "~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh"
```

Expected: no output, no error. A new resurrect file in `~/.local/share/tmux/resurrect/`.

- [ ] **Step 6: Verify save file**

```bash
ls -la ~/.local/share/tmux/resurrect/last
head -20 ~/.local/share/tmux/resurrect/last
```

Expected: file exists; head shows pane records including any running `nvim`/`claude`/`lazygit`.

- [ ] **Step 7: Commit**

```bash
git add dot_config/tmux/tmux.conf
git commit -m "feat(tmux): tune resurrect/continuum for shorter save interval and process restore"
```

---

## Task 7: Fix Ghostty autostart (conditional on Task 1 result)

**Files:**
- Modify: `dot_config/nushell/autoload/ghostty.nu` (only if Task 1 = case B)

**Outcome from Task 1:** _record here: case A (server survived) → SKIP this task | case B (server died) → DO this task_

- [ ] **Step 1: Only if case B — open the file**

```bash
cat /Users/greg/Code/dotfiles/dot_config/nushell/autoload/ghostty.nu
```

Current content:

```nu
if ($env.TMUX? == null) and not ($env.SSH_CONNECTION? != null) and ($env.TERM? == "xterm-ghostty") {
    exec tmux new-session -A -s ghostty
}
```

- [ ] **Step 2: Replace with explicit server start**

Edit to:

```nu
if ($env.TMUX? == null) and not ($env.SSH_CONNECTION? != null) and ($env.TERM? == "xterm-ghostty") {
    # Ensure server is daemonized before attaching, so closing Ghostty
    # does not propagate SIGHUP to the server process group.
    ^tmux start-server
    exec tmux new-session -A -s ghostty
}
```

- [ ] **Step 3: Apply chezmoi**

```nu
chezmoi apply
```

- [ ] **Step 4: Re-run Task 1 diagnostic**

Repeat Task 1 steps 1-4 to confirm server now survives.

- [ ] **Step 5: Commit**

```bash
git add dot_config/nushell/autoload/ghostty.nu
git commit -m "fix(nu): daemonize tmux server before Ghostty attach to survive app quit"
```

---

## Task 8: Create ssh-tmux.nu autoload

**Files:**
- Create: `dot_config/nushell/autoload/ssh-tmux.nu`

- [ ] **Step 1: Write the file**

Create `/Users/greg/Code/dotfiles/dot_config/nushell/autoload/ssh-tmux.nu` with:

```nu
# SSH auto-sesh
# When logging into a remote machine via SSH and not yet in tmux,
# open the sesh picker. Detaching via `prefix d` returns to the
# nushell prompt; closing the connection leaves the tmux server
# running on the remote.
#
# Local Ghostty is handled separately by ghostty.nu.

if ($env.SSH_CONNECTION? != null) and ($env.TMUX? == null) and ($env.SSH_TTY? != null) {
    if (which sesh | is-not-empty) {
        exec sesh connect
    } else {
        # Fallback: attach or create a single 'main' session
        exec tmux new-session -A -s main
    }
}
```

- [ ] **Step 2: Apply chezmoi locally**

```nu
chezmoi apply
```

This places the file at `~/.config/nushell/autoload/ssh-tmux.nu`. It will not fire locally (no `SSH_CONNECTION`), but will be picked up when chezmoi-applied on the lab.

- [ ] **Step 3: Commit**

```bash
git add dot_config/nushell/autoload/ssh-tmux.nu
git commit -m "feat(nu): auto-open sesh picker on SSH login"
```

---

## Task 9: Add SSH config alias for lab

**Files:**
- Create: `private_dot_ssh/config.tmpl` (in dotfiles repo)
- Backup: `~/.ssh/config` (manual, outside repo)

**Why private_:** chezmoi enforces 0600 on `private_` prefixed sources. SSH config requires restricted perms.

- [ ] **Step 1: Back up existing SSH config**

```bash
cp ~/.ssh/config ~/.ssh/config.bak
echo "Backup created at ~/.ssh/config.bak — keep until lab connection confirmed working"
```

- [ ] **Step 2: Read existing config contents to preserve**

```bash
cat ~/.ssh/config
```

Note any existing `Host` blocks. You will inline them into the new templated file in Step 4.

- [ ] **Step 3: Create the dotfiles source**

```bash
mkdir -p /Users/greg/Code/dotfiles/private_dot_ssh
```

- [ ] **Step 4: Write the template**

Create `/Users/greg/Code/dotfiles/private_dot_ssh/config.tmpl` with:

```
# Managed by chezmoi. Edit the source: ~/Code/dotfiles/private_dot_ssh/config.tmpl

Host lab
    HostName 192.168.50.10
    User greg
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Paste any existing host entries from ~/.ssh/config.bak below this line
# (preserve their formatting verbatim)
```

If the backup contained entries, paste them after the template comment line.

- [ ] **Step 5: Apply chezmoi**

```nu
chezmoi apply
```

If chezmoi refuses with "destination already exists", run:

```bash
chezmoi merge ~/.ssh/config
```

and accept the templated version, or remove the destination first:

```bash
rm ~/.ssh/config && chezmoi apply
```

- [ ] **Step 6: Verify permissions and content**

```bash
ls -l ~/.ssh/config
cat ~/.ssh/config
```

Expected: `-rw-------` (mode 0600). Lab block present.

- [ ] **Step 7: Test the alias**

```bash
ssh -o BatchMode=yes -o ConnectTimeout=5 lab "echo lab reachable"
```

Expected: `lab reachable` printed. If permission denied, confirm `~/.ssh/id_ed25519` is the right key for that host.

- [ ] **Step 8: Commit**

```bash
git add private_dot_ssh/config.tmpl
git commit -m "feat(ssh): add lab host alias (chezmoi private template)"
```

---

## Task 10: Bootstrap lab — install sesh and apply chezmoi

**Files:** none in this repo; this is remote machine setup.

- [ ] **Step 1: SSH to lab**

```bash
ssh lab
```

- [ ] **Step 2: Verify chezmoi is up to date on lab**

On lab:

```bash
chezmoi update --apply
```

Expected: pulls latest from the dotfiles git remote, applies all changes including the new sesh.toml, ssh-tmux.nu, tmux.conf updates, and wrappers.

- [ ] **Step 3: Install sesh via linuxbrew**

On lab:

```bash
brew install sesh
which sesh
```

Expected: path under `/home/linuxbrew/.linuxbrew/bin/sesh`.

- [ ] **Step 4: Verify fzf-tmux on lab**

```bash
which fzf-tmux
```

Expected: path printed. If missing, `brew install fzf`.

- [ ] **Step 5: Verify nushell autoload picked up ssh-tmux.nu**

On lab:

```bash
ls ~/.config/nushell/autoload/ssh-tmux.nu
```

Expected: file exists.

- [ ] **Step 6: Test sesh on lab manually**

On lab (already inside SSH session, but not in tmux):

```bash
sesh list
```

Expected: a list (possibly empty plus zoxide entries).

- [ ] **Step 7: Exit SSH (no commit, no changes in repo)**

```bash
exit
```

---

## Task 11: End-to-end SSH flow verification

**Files:** none — verification only.

- [ ] **Step 1: From Mac, run ssh lab**

```bash
ssh lab
```

Expected: instead of dropping at a nushell prompt, you should see the sesh fzf picker (full-screen).

- [ ] **Step 2: Create a session by picking an entry**

Pick any entry (or type a new name and Enter for fresh). You should land in a tmux session, window 1 named `  term`.

- [ ] **Step 3: Verify wrappers work on lab**

In window 1, type:

```nu
lazygit
```

(Assuming you have a git repo cwd; if not, `cd /tmp && git init test && cd test && lazygit`.)
Expected: new window `  git` runs lazygit.

- [ ] **Step 4: Detach and confirm server survives**

`prefix d` → back to nu prompt. Then:

```bash
exit
```

This closes SSH. From Mac:

```bash
ssh lab "pgrep -lf 'tmux: server'"
```

Expected: tmux server PID printed (server still running).

- [ ] **Step 5: Reconnect and confirm session restored**

```bash
ssh lab
```

Expected: sesh picker shows your previous session in the list. Picking it reattaches with windows intact.

- [ ] **Step 6: Confirm continuum saves on lab**

In the lab tmux:

```bash
ls -la ~/.local/share/tmux/resurrect/
```

Expected: a `last` file (or `last.txt`) less than 5 minutes old.

- [ ] **Step 7: No commit — pure validation.**

---

## Task 12: Restore manual backup if needed and finalize

**Files:** cleanup only.

- [ ] **Step 1: Confirm lab works**

If Task 11 passed all steps, the lab flow is good.

- [ ] **Step 2: Decide on `~/.ssh/config.bak`**

If all hosts work, delete it:

```bash
rm ~/.ssh/config.bak
```

If something broke, restore:

```bash
mv ~/.ssh/config.bak ~/.ssh/config
```

And revert Task 9 commit (`git revert <sha>`).

- [ ] **Step 3: Final smoke test on Mac**

Close all Ghostty windows. Open a fresh one. Expect:

- Land in tmux session `ghostty`.
- `prefix f` opens sesh picker.
- Picking `dotfiles` (or any project) creates a new session, W1 named `  term`.
- Typing `claude`, `nvim`, `lazygit` spawns iconed windows.

- [ ] **Step 4: Done — no further commit unless cleanup happened.**

---

## Validation checklist (post-implementation)

Mirror of the spec's checklist:

- [ ] `brew install sesh` works on both machines (linuxbrew on lab, homebrew on Mac).
- [ ] `sesh list` shows expected projects on each machine.
- [ ] `ssh lab` lands directly in sesh picker.
- [ ] Disconnecting SSH leaves tmux server alive on lab (`ssh lab "pgrep -lf 'tmux: server'"`).
- [ ] `claude` / `nvim` / `lazygit` typed in W1 spawn correctly named/iconed windows.
- [ ] `automatic-rename` does NOT overwrite explicit names (`tmux show-window-options -v automatic-rename` → `off`).
- [ ] Existing `vim`/`vi`/`v` aliases still work.
- [ ] Reboot of Mac: Ghostty reopens, attaches to `ghostty`, previous sessions restored by continuum.
- [ ] `redocly` does not appear in any committed dotfile (`grep -ri redocly ~/Code/dotfiles --include='*.toml' --include='*.nu' --include='*.tmpl' --include='*.conf' --include='*.sh'` → empty).

---

## Rollback

If something goes badly wrong:

```bash
cd ~/Code/dotfiles
git log --oneline -15        # find commits from this plan
git revert <last-good>..HEAD # revert all plan commits
chezmoi apply
```

For SSH: `mv ~/.ssh/config.bak ~/.ssh/config` if backup still exists.
