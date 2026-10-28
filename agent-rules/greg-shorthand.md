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
| `kończymy`, `zamykamy` | close the session | `/retro`, then commit and push what is left, then close this agent. In a worktree: `workctl done` (Greg's `prefix+X`) removes the worktree, branch and session, and refuses with a list when anything is uncommitted or on no remote; that list gets one line (2026-10-21). It ends with exit 137 next to `✅ removed …`: it kills its own shell with the session, so that is success. Don't retry and don't verify from this session (4 sessions, 2026-10-21). |
