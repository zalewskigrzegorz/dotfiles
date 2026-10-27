# tuios on Windows — connect to the lab

Goal: from the Windows machine, get a tuios session on the lab drawn in a local client, so
the prefix and clipboard pass through correctly (the thing Alacritty → lab-tmux never managed).

This is **not** chezmoi-managed. The dotfiles are Mac/Linux only; on Windows you install and
configure tuios by hand. This file is the runbook. Nothing here was verified on the Windows
machine since the switch from herdr; the facts come from the tuios docs.

## 1. Install tuios

Pre-built Windows binaries are on the releases page (<https://github.com/Gaurav-Gosain/tuios/releases>).
Daemon sessions need Windows build 17063 or later (Unix socket support). A terminal that
speaks the enhanced keyboard protocol helps (WezTerm, recent Windows Terminal).

## 2. SSH to the lab must work first

Make sure `ssh mrglaszki` works from Windows (copy the `mrglaszki` Host block from the Mac
`~/.ssh/config`, adjust the key path), and accept the host key by hand once: tuios dials with
`BatchMode`, so it never asks. Win32-OpenSSH has no `ControlMaster`, which tuios tolerates.

```
ssh mrglaszki
```

## 3. Connect as a thin client

The lab keeps your sessions and agents. Add it as a host and attach:

```
tuios hosts add mrglaszki mrglaszki --command /home/linuxbrew/.linuxbrew/bin/tuios
tuios hosts test mrglaszki
tuios attach --host mrglaszki
```

The session is drawn in the Windows client with its own config and prefix; nothing is nested.
`tuios attach --host mrglaszki --ssh` (ssh to the lab and run its tuios there, remote client
nested in yours, prefix pressed twice) is the fallback when the lab's tuios is too old for
this client.

## 4. Config (by hand)

Keep it small: a `config.toml` with the leader key (`ctrl+space`) and a `preferred_shell`
for Windows (nu / pwsh). The Mac one (`dot_config/tuios/config.d/readonly_10-dotfiles.toml.tmpl`,
rendered) is a starting point. The heavy config lives on the lab you attach to.

## Status

If the Windows build or the host link misbehaves, fall back to `ssh mrglaszki` and run `tuios`
on the lab directly.
