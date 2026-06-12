---
name: reminders
description: Read and write Greg's real Apple Reminders from the terminal via the `reminders` CLI (keith/reminders-cli, binary in ~/.local/bin, macOS-only via EventKit). Use whenever Greg wants to capture, list, complete, or edit tasks/reminders — phrases like "dodaj do reminders", "przypomnij mi", "co mam do zrobienia", "moje taski", "pokaż listę X", "wrzuć na listę zakupów", "odhacz", "zrobione", "add a reminder", "remind me to", "what's on my to-do", "show my tasks", "mark done", "add to groceries". These are Greg's actual Apple Reminders — the same data on his Apple Watch and iPhone, so any change here shows up on all his devices. macOS only; do NOT use this on the lab.
---

# Reminders — Apple Reminders from the terminal

Greg's task manager is **Apple Reminders**. Access it with the `reminders` CLI
(`keith/reminders-cli`), a prebuilt binary at `~/.local/bin/reminders`. This is
**macOS-only** (uses EventKit) — it does not exist on the lab. Edits sync to his
Apple Watch + iPhone, so treat writes as real and user-visible.

Reproducible install: `run_once_after_40-install-reminders-cli.sh.tmpl` in
dotfiles (NOT Homebrew — brew's sandbox can't build it on Greg's Mac, see the
`homebrew-6-mac-gotchas` memory).

## Always discover lists first

List names can change. Never assume — run this before any list-specific action:

```bash
reminders show-lists
```

Greg's lists as of 2026-06-12 (verify, don't trust): `Reminders`, `DeskMinder`,
`To do`, `Daily Brief`, `Groceries`.

## Core commands

```bash
reminders show "To do"                     # open items on a list (indexed 0,1,2…)
reminders show "To do" --include-completed  # include done items
reminders show "To do" --sort due-date -o ascending
reminders show-all                          # every item across all lists

reminders add "To do" "Reply to Anna" --due-date "tomorrow 9am" --priority high --notes "re: Q3 plan"
reminders complete "To do" 2                # mark item at index 2 done
reminders uncomplete "To do" 2
reminders edit "To do" 2 "New text"
reminders delete "To do" 2

reminders new-list "Projects"
```

- `--priority`: one of `none`, `low`, `medium`, `high` (default `none`).
- `--due-date`: natural language works (`"tomorrow 9am"`, `"friday"`, `"2026-06-20 17:00"`).

## Parsing output programmatically

For anything beyond showing the user raw text, use JSON — don't scrape the
plain format:

```bash
reminders show "To do" --format json
reminders add "Groceries" "Milk" --format json
```

## Critical gotcha: indices are positional and shift

Items are addressed by their **position index** (0,1,2…), not a stable ID.
After any `complete`/`delete`/`add`, indices renumber. So:

1. `reminders show "<list>"` (or `--format json`) to get current indices,
2. act on the index **immediately**,
3. re-show if you need to act again.

Never reuse an index from an earlier output across a mutating command.

## Behaviour

- **Before writing**, confirm the target list and text with Greg if ambiguous —
  these go straight to his devices.
- When he says "dodaj X" without a list, default to `Reminders` (the inbox) or
  ask if a specific list fits better (e.g. shopping → `Groceries`).
- When showing tasks, render the plain output; only fall back to JSON when you
  need to filter/transform.
- First run on a fresh machine triggers a macOS permission prompt for Reminders
  access — if `show-lists` returns empty, that grant is missing.
