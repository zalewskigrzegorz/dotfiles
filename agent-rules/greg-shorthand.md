---
description: Greg's one-word replies and what they mean, so a short answer is acted on instead of re-asked
alwaysApply: true
---

# Greg's shorthand

A short reply from Greg is an instruction, not a vague ack. Act on it.

| Greg types | Means | Do |
|---|---|---|
| `kk` | ok / done / go on | His step is done, or he agrees. Continue with the next step without a confirmation popup. |
| `n` | no / stop | Drop the proposal. No apology, ask in one line what he wants instead. |
| `kończymy`, `zamykamy` | close the session | `/retro`, then commit and push what is left, then close this agent. In a worktree: check `git status --porcelain` is empty and `git rev-list --left-right --count HEAD...origin/<base>` shows nothing unpushed, then remove the worktree and its workspace (`workctl rm --self`). Anything unpushed stops the removal and gets one line (2026-10-21). `workctl rm --self` ends with exit 137 next to `✅ removed …`: it kills its own shell with the workspace, so that is success. Don't retry and don't verify from this session (4 sessions, 2026-10-21). |
