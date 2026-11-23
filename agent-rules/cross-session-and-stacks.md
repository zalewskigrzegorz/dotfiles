---
description: Answer a cross-session message straight to the sending agent; fetch the base (stacked branch or main) and the branch itself and read what landed before designing, committing, asking or opening the PR
alwaysApply: true
---

# Other Agents and Stacked Bases

## A `<cross-session-message>` gets its answer from you, not through Greg

Another Claude session asking for an export, a signature or a sha (`from=`, `from-name=`) is answered with `SendMessage` to that sender (`ListAgents` if the name is unclear): exact signatures and the commit sha, before the next item. Greg gets one status line, not a relay (a752428e).

## After a resume, look for a twin before taking the next queued item

A conversation resumed in two panes runs twice (both copies worked one `sprawy` queue; it surfaced only as "File has been modified since read"). After a resume or reboot, and before each queued item: `git log --oneline -5` against your own last commit and `tuios list-agents -s "$TUIOS_SESSION"`. A commit you didn't make on your item, or a second pane with your task title → stop, say so in one line, leave the item to that pane.

## Fetch the base before you design, commit, ask or open a PR

Sessions on a stale local view opened a PR into a conflict, asked about "no PR" while one existed, read prod from an old worktree, and designed against a base that had gained an ADR ("na branch wszedł adr 15, weź go pod uwagę").

- **Stacked on a non-main base** (cycle branch, earlier PR): `git fetch origin <base>` + `git log --oneline HEAD..origin/<base>` at the task start, before the first commit, and before opening or updating the PR. New commits touching ADRs or docs → read them, say in one line which applies. A second PR depending on an unmerged first → propose stacking it up front (`workctl --base origin/<first-branch>`).
- **Cut from `main`**: before the first commit and before push / `gh pr create`: `git fetch origin main` + `git log --oneline HEAD..origin/main -- <paths you touched>`; a hit → read that commit and rebase now. Right after opening: `gh pr view <n> --json mergeable,mergeStateStatus`; `CONFLICTING`/`DIRTY` → rebase, no "co dalej" popup.
- **Work on an existing branch**: `git fetch origin <branch>`, `git rev-list --left-right --count HEAD...origin/<branch>` and `gh pr list --head <branch> --state all` before any fork about PRs, rebase or merge. A brief's "no PR yet" is a claim to check; remote differs or a PR exists → one line first.
- **"Why does prod do X"**: when the worktree is behind, read `origin/main` (`git show origin/main:<path>`, `git grep <pat> origin/main`) and name the sha.
- **A question about another open PR**: read its diff first (`git ls-tree`, `git show` on its branch); only what it doesn't settle goes to Greg.
- **After a rebase or merge from `main`, run what CI runs before the push**; red locally = no push. Monorepo commands, stacked-branch triage, e2e label traps: `~/.claude/rules/work-ci-and-rebase.md` (loads with monorepo files).

## History rewrites and hand-offs

- **Squash/amend and push in separate calls.** `old=$(git rev-parse HEAD)` as backup; before the push `git rev-list --count origin/main..HEAD` ≥1 and `git diff --stat <old> HEAD`; no `;` between `reset --soft` and the push (a HEAD equal to the merge-base once closed the PR, 255f38c7).
- **Before `gh pr create --base <b>`:** `git ls-remote --heads origin <b>`. Empty = base merged and deleted: `git rebase --onto origin/main <last base commit>`, never the same create again.
- **A brief says "the file lands on main now"**: before the "gotowe" mail, fetch, `git log HEAD..origin/main -- <file>`, rebase, sha in the mail.
- **"Mail me before polishing" is a gate**: after the mail only the independent part, and one line "czekam na go/no-go".
