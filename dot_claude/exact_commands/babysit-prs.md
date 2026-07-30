---
description: Autonomously keep Greg's open PRs green — one pass, no confirmations. Wrapper around the babysit-prs skill so it can be invoked from any repo.
argument-hint: "[optional PR number or filter]"
---

Use the `babysit-prs` skill for this task and follow it exactly.

The skill is work-scoped (placed only into the work monorepo and its worktrees by
`bin/place-work-skills`), so this command exists to invoke it by name from
anywhere. If the skill is not available in the current repo, say so plainly
rather than improvising a substitute flow.

One pass per invocation. No confirmations — that is the point of this command.

$ARGUMENTS
