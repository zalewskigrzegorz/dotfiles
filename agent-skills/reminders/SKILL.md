---
name: reminders
description: Read and write Greg's real Apple Reminders (synced to his iPhone and Watch) with the `reminders` CLI (keith/reminders-cli, ~/.local/bin, macOS only). Use on "dodaj do reminders", "przypomnij mi", "co mam do zrobienia", "moje taski", "pokaż listę X", "wrzuć na listę zakupów", "odhacz", "zrobione", "add a reminder", "remind me to", "what's on my to-do", "show my tasks", "mark done", "add to groceries". Never on the lab.
---

# Reminders

Writes land on all his devices: treat them as real. Installed by `run_once_after_40-install-reminders-cli.sh.tmpl` (not Homebrew: its sandbox can't build it here).

```bash
reminders show-lists                         # always first; names change (2026-06: Reminders, DeskMinder, To do, Daily Brief, Groceries)
reminders show "To do" [--include-completed] [--sort due-date -o ascending] [--format json]
reminders show-all
reminders add "To do" "Reply to Anna" --due-date "tomorrow 9am" --priority high --notes "…"   # priority none|low|medium|high
reminders complete|uncomplete|delete "To do" 2
reminders edit "To do" 2 "New text"
reminders new-list "Projects"
```

- **Indices are positional and renumber after every add/complete/delete**: show, act at once, re-show before the next mutation. Never reuse an old index.
- `--format json` for filtering/transforming; plain output when just showing him.
- Ambiguous list or text → confirm before writing. "Dodaj X" without a list → `Reminders` (inbox), or the obvious one (shopping → `Groceries`).
- Empty `show-lists` on a fresh machine = the Reminders grant is missing (`grant-failure-ask.md`).
