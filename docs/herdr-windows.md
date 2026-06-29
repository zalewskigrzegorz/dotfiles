# herdr on Windows — connect to the lab (Phase 10)

Goal: from the Windows machine, get a herdr **client-server** session against the
herdr server running on the lab — so the prefix and clipboard pass through
correctly (the thing Alacritty → lab-tmux never managed).

This is **not** chezmoi-managed. The dotfiles are Mac/Linux only; on Windows you
install + configure herdr by hand. This file is the runbook.

## 1. Install herdr (preview/beta on Windows)

herdr's Windows build is preview-only. Install via the method noted on
<https://herdr.dev> / the GitHub releases (`ogulcancelik/herdr`) — typically the
preview channel:

```
herdr channel set preview
herdr update
```

(If there's a Windows installer/scoop/winget entry by the time you do this, prefer that.)

A terminal that speaks the enhanced keyboard protocol helps (WezTerm / Windows
Terminal recent builds / Ghostty-Windows when it lands).

## 2. SSH to the lab must work first

`herdr --remote` rides your SSH config. Make sure `ssh lab` works from Windows
(copy the `lab` Host block from the Mac `~/.ssh/config`, adjust key path). Test:

```
ssh lab
```

## 3. Connect as a thin client

The lab runs the herdr **server** (your sessions/agents live there):

```
# on the lab (once):
herdr            # starts/attaches the server + your workspaces
```

From Windows, attach a thin client over SSH:

```
herdr --remote lab
# or explicit:  herdr --remote ssh://greg@192.168.50.10
```

This is client-server, not plain ssh+tmux: the prefix is carried correctly, plus
a clipboard/image bridge. `[remote] manage_ssh_config = true` (herdr default) adds
keepalive (ServerAliveInterval) on top of your `~/.ssh/config`.

## 4. Config (by hand)

Drop a minimal `~/.config/herdr/config.toml` if you want overrides (prefix, theme).
You can copy the Mac one (`~/Code/dotfiles/dot_config/herdr/config.toml.tmpl`,
rendered) as a starting point and adjust `default_shell` for Windows (e.g. nu /
pwsh). Keep it small — the heavy config lives on the lab server you attach to.

## Status

Deferred until the Mac + lab migration is settled. No fallback engineering — if the
preview build or `--remote` misbehaves, fall back to `ssh lab` + tmux on the lab.
