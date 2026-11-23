---
description: Greg's one-word replies and what they mean, so a short answer is acted on instead of re-asked
alwaysApply: true
---

# Greg's shorthand

A short reply is an instruction, not a vague ack. Act on it.

| Greg types | Do |
|---|---|
| `kk` | His step is done or he agrees: continue, no confirmation popup. |
| `zaktualizuj maina` | `git -C <main checkout> pull --ff-only origin main` (main checkout = parent of `git rev-parse --git-common-dir`), only when clean and on `main`. Worktree and feature branch stay; rebase only on "zrebase'uj" or before a PR (fa996d11). |
| `n` | Drop the proposal. No apology; ask in one line what he wants instead. |
| `cofnij`, `wycofaj`, `undo` | Reverse only what you did yourself, or ask. After a delete it is never consent to another delete; a destructive button needs a named "usuń to". |
| `<N> <name>` (with a screenshot) | Agent number N in the tuios sidebar: newest screenshot first, then one `tuios list-agents --all`. |
| `kończymy`, `zamykamy` | `/retro`, commit and push what is left, close this agent. In a worktree: `workctl done` (his `prefix+X`) removes worktree, branch and session, or refuses with a list of what is uncommitted / on no remote (one line on it). Exit 137 next to `✅ removed …` is success; don't retry or verify. |
