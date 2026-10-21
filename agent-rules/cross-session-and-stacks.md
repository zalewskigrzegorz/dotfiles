---
description: Answer a cross-session message straight to the sending agent; fetch the base (stacked branch or main) and the branch itself and read what landed before designing, committing, asking or opening the PR
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

## `main` moves too — fetch before you commit, ask or open a PR

The stacked-base check above applies to a branch cut from `main` as well. Four
sessions (2026-10-12 … 10-16) acted on a stale local view: a PR opened into a
conflict Greg spotted first (02be04c1), two popups built on "the branch has no
PR" while one existed and had been rebased on the remote (4bf5a457), a prod
investigation read an old worktree instead of what prod runs (13ddf2cf), and
a "do decyzji" question that the other open PR already answered (2f5fe621).

- **Before the first commit and before push / `gh pr create`:** `git fetch
  origin main` and `git log --oneline HEAD..origin/main -- <paths you
  touched>`. A hit → read that commit and rebase now. Right after opening the
  PR: `gh pr view <n> --json mergeable,mergeStateStatus`; `CONFLICTING` or
  `DIRTY` → rebase first, no "co dalej" popup.
- **Work on a branch that already exists:** `git fetch origin <branch>`, `git
  rev-list --left-right --count HEAD...origin/<branch>` and `gh pr list --head
  <branch> --state all` before any fork about PRs, rebase or merge. A brief's
  "no PR yet" is a claim to check. Remote differs or a PR exists → say so in
  one line first.
- **"Why does prod do X":** `git fetch origin main` and read `origin/main`
  (`git show origin/main:<path>`, `git grep <pat> origin/main`) when the
  worktree is behind. Say in one line which sha you read.
- **A question about another open PR:** read its diff first (`git ls-tree`,
  `git show` on its branch). Only what the diff does not settle goes to Greg.

## After a rebase or merge from `main`: run what CI runs, then push

Four red checks after a rebase (a moved test helper, two stale imports): "czy
ty tego nie sprawdzasz lokalnie najpierw?" (df44b632). A 16-commit rebase with
~25 conflicted files lost a function, a `start.sh` block and a test path
silently (c333538c).

- Before the push: `pnpm exec nx run-many -t knip:check ts:check lint -p
  <project>` in the background; touched `*.db.spec.ts` on their own database
  (see the local Docker rule). Red locally = no push. "0 passed, skipped
  without a database" is not green.
- A file `main` moved → `git grep` the old import path first.
- ≥10 files resolved by hand → `git diff origin/main...HEAD --diff-filter=M
  -U0 | rg '^-[^-]'` (every removed line belongs to the change) and `git
  range-diff` against the old ref.
- Changed test files → the package's `ts:check` too: vitest does not
  type-check, and a PR sat red for a full e2e cycle on that (9adba92d).

## Red check on a stacked branch → compare with the base first

Lint, knip or a spec red on a branch stacked on a non-main base: before
touching code, run `rg-base-head <pattern> [paths] --base origin/<base>` (or
the check itself on the base). Same hits on both → report in one line
("identyczne na base, nie nasze") and leave them. It took ~15 calls twice in
one session (2026-10-08).
