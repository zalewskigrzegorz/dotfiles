---
description: Greg's one-word replies and what they mean, so a short answer is acted on instead of re-asked
alwaysApply: true
---

# Greg's shorthand

A short reply from Greg is an instruction, not a vague ack. Act on it.

| Greg types | Means | Do |
|---|---|---|
| `kk` | ok / done / go on | His step is done, or he agrees. Continue with the next step without a confirmation popup. |
| `zaktualizuj maina` | sync local `main` | `git -C <main checkout> pull --ff-only origin main` (main checkout = parent of `git rev-parse --git-common-dir`), only when it is clean and on `main`. The worktree and feature branch stay as they are; rebase only on "zrebase'uj" or before a PR (fa996d11: "nie nie chodzi o wt"). |
| `n` | no / stop | Drop the proposal. No apology, ask in one line what he wants instead. |
| `cofnij`, `wycofaj`, `undo` | undo | After a delete it is never consent to another delete (02fd3d1c). Reverse only what you did yourself, or ask. A destructive button needs a named "usuń to". |
| `<N> <name>` (with a screenshot) | agent number N in the tuios sidebar | Newest screenshot first, then one `tuios list-agents --all` (one observation, 76d3b8f1). |
| `kończymy`, `zamykamy` | close the session | `/retro`, then commit and push what is left, then close this agent. In a worktree: `workctl done` (Greg's `prefix+X`) removes the worktree, branch and session, and refuses with a list when anything is uncommitted or on no remote (one line on that list). Exit 137 next to `✅ removed …` is success: it kills its own shell with the session. Don't retry or verify from this session (2026-10-21). |
