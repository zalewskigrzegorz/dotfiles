---
description: Answer a cross-session message straight to the sending agent; on a branch stacked on a non-main base, fetch the base and read what landed before designing, committing or opening the PR
alwaysApply: true
---

# Other Agents and Stacked Bases

## A `<cross-session-message>` gets its answer from you, not through Greg

Another Claude session asking for an export, a signature or a sha (`from=`,
`from-name=` on the message) is answered with `SendMessage` to that sender —
`ListAgents` if the name is unclear. Put the exact signatures and the commit
sha in it, and reply before moving on to the next item. Greg gets one status
line, not a relay of the answer. On 2026-10-04 two requests were summarised to
Greg in prose until he asked "może bezpośrednio napisz do agentów?" (a752428e).

## A branch stacked on a non-main base tracks that base

When the base is another feature branch (a cycle branch, an earlier PR),
commits land there while you work. On 2026-10-04 an ADR landed on the base
while the design was being written against the stale copy. Greg: "na branch
wszedł adr 15, weź go pod uwagę, bo teraz tego nie robisz" (a752428e).

- `git fetch origin <base>` and `git log --oneline HEAD..origin/<base>` at
  three points: the start of the task, before the first commit, and before
  opening or updating the PR.
- New commits that touch ADRs or docs → read them first and say in one line
  which one applies.
- A second PR that depends on an unmerged first one → propose stacking it on
  that PR up front (`workctl --base origin/<first-branch>`). Don't wait for
  Greg to ask.
