---
paths:
  - "run_*"
  - "private_dot_ssh/**"
  - "bootstrap.sh"
---

# Lab (`minis`, Debian)

- **Connect:** `ssh mrglaszki` (chezmoi-templated `~/.ssh/config`), `HostName 192.168.50.10` on purpose: AdGuard runs on that host, so ssh must not depend on its DNS. DNS `mrglaszki` → 192.168.50.10 is an AdGuard rewrite; the old `lab` name and `*.lab` rewrites are gone (2026-10-23).
- **tuios runs there too.** From the Mac, outside a tuios pane: `os-mrglaszki` (`tuios attach --host mrglaszki`, `[hosts.mrglaszki]`) draws the lab session in a plain Ghostty window, nothing nested (`docs/tuios.md`).
- **Terminfo, once per remote**, so nvim accepts `xterm-ghostty`: `infocmp -x xterm-ghostty | ssh <host> -- tic -x -`.
- Login shell is `bash`: run `nu` after login, or `chsh -s $(which nu)` after adding nu to `/etc/shells`.
- **Update:** `chezmoi update` from bash (git pull in `~/.local/share/chezmoi` + apply). `~/Code/dotfiles` there is NOT a git checkout.

## `run_*` scripts on the lab

The lab's `rsync` and other brew tools sit in `/home/linuxbrew/.linuxbrew/bin`, missing from a non-interactive PATH (stage 28 failed while 30 and 33 worked, fixed in `88c008e`).

- A script calling `rsync` or any brew tool exports the linuxbrew PATH at its top, as stage 30 does. Mac-only stages (`if eq .chezmoi.os "darwin"`) are exempt.
- Check with `ssh mrglaszki 'command -v rsync'`.
