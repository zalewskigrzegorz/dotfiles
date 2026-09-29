---
description: Sweep every pending /retro session (all repos) in one batch on Sonnet, then merge the proposals into one popup. Explicit-invoke command; replaces the per-session nudge.
allowed-tools: Bash(retro-backlog:*), Bash(wc:*), Bash(cat:*), Read, Write, AskUserQuestion, mcp__hindsight__retain
---

Pending sessions right now:

!`retro-backlog --list`

Run the batch, then consolidate. Say the count and the model in one line before starting ("N sesji, Sonnet, 6 równolegle, ~<N/6 × 1.5> min").

1. `retro-backlog` in the background (Bash `run_in_background`, timeout 600000). It prints the output dir and a status table; a line `STUB … re-running` means a sub-1 KB output was retried once.
2. When it finishes, `cat` every `<id>.md` in the output dir into one file and read it. Ignore `.err` files unless a status line has `exit=` other than 0.
3. Merge: group proposals that hit the same target file or the same mechanism into clusters, count how many sessions raised each, drop anything already materialized (check the target file) and anything team-owned (work monorepo `CLAUDE.md`, its tracked `.claude/skills/*`). Flag security findings (a token printed to a transcript) at the top, outside the tiers.
4. Write the report to `~/Code/personal/bazgroly/dotfiles/analysis/YYYY-MM-DD-retro-backlog.md`: tiers by (sessions raised × cost to apply), each cluster with target file, session ids and the concrete how-to. It is the reference; the popup only names tiers.
5. One `AskUserQuestion`, multiSelect, ≤4 options = tiers (Tier 1 recommended). Then materialize per `agent-rules/retro-adapter.md`: rules and skills in `~/Code/dotfiles`, facts via `mcp__hindsight__retain`, home-lab into its own `CLAUDE.md`. Finish with `bin/sync` and `g-commit`.

The tsv is already empty after step 1 (each child session cleared its id), so a crashed consolidation does not re-run the batch; the outputs stay under `~/.local/state/dotfiles/retro-backlog/`.
