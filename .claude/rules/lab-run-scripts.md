---
paths:
  - "run_*"
---

# `run_*` scripts on the lab

The lab's `rsync` and other brew tools sit in `/home/linuxbrew/.linuxbrew/bin`,
which a non-interactive script's PATH lacks: stage 28 failed there while 30
and 33 worked (fixed in `88c008e`, a8b9bde2).

- A script that calls `rsync` or any brew tool exports the linuxbrew PATH at
  its top, as stage 30 does.
- Check with `ssh mrglaszki 'command -v rsync'` (non-interactive shell).
- Mac-only stages (behind `if eq .chezmoi.os "darwin"`) are exempt.
