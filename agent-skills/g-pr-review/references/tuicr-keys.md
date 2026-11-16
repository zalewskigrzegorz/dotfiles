# tuicr keys for the review hand-over

Checked on tuicr 0.28.0 (2026-11-03). Recheck after an upgrade.

- Diff view: `m` / `M` jump to the next / previous draft, `dd` deletes it, `c` adds one.
- `:summary` (or `:su` + Tab + Enter) is a bare list. `dd` and `c` do nothing there. Enter jumps to the code, `Esc` goes back to the diff.
- `:submit` picks Comment / Approve / Request changes / Draft and is the only thing that reaches GitHub.
- There is no keymap of its own in the config, so don't promise rebinding.
