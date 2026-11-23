---
name: g-pr-fix-checks
description: Rebases Greg's open GitHub PRs that fail checks or conflict with the base, force-pushes with lease, retriggers the run_e2e label. Use for "fix failing checks", "rebase the PR", "retrigger e2e", "my PRs are conflicting", or PRs that went red after the base moved.
---

# g-pr-fix-checks

Recovers Greg's own open PRs in the current repo (`cd` there first) when the
base got fixed after breaking tests/e2e/types, or moved on and now conflicts.
Scripts do the deterministic work; you stop only for real decisions (which
PRs, how to handle a conflict).

## Prerequisites

`gh repo view` works, `gh auth status` is logged in, `git status --porcelain`
is empty. Dirty → stop and say so (never `git stash` in a shared checkout).
Any prereq fails → report exactly what's missing, stop.

## 1. List

`bash scripts/list_prs.sh` → one line per open PR of mine, current branch's
first: `<number>\t<state>\t<mergeable>\t<failed_checks>\t<head>\t<base>\t<title>`.
`state` = `FAILING|PENDING|PASSING|UNKNOWN`, `mergeable` =
`MERGEABLE|CONFLICTING|UNKNOWN`, `failed_checks` comma-separated or `-`.
Actionable = `FAILING` or `CONFLICTING` (`UNKNOWN` mergeable alone is not).

## 2. Pick

- None actionable → "no failing or conflicting PRs, nothing to do", stop.
  Never rebase a green, mergeable PR.
- One, and it's the current branch's → confirm in one sentence (failing /
  conflicting / both, failed checks), proceed.
- Otherwise ask which (one, several, all), each PR as `#<num> <failing|
  conflicting|failing+conflicting> <branch> ← <title>` plus `failed: <checks>`
  when failing. Terse: no clean PRs, no raw TSV.

## 3. Update each

**Only the Project preview (intranet/docs build) red?** First `git fetch -q
origin && git rev-list --count HEAD..origin/<base>`: >~50 behind means a stale
dependency and the rebase fixes it (~40 turns went into restarts before this
count once). Wait for a rerun with `gh-run-wait <workflow> --sha HEAD`.

`bash scripts/update_pr.sh <pr-number>`: remembers the branch, `gh pr
checkout`, fetch + `git rebase origin/<base>`. Exit 0 = pushed
`--force-with-lease` and `run_e2e` toggled. Exit 2 = conflict, left
mid-rebase, files printed. Exit 1 = other failure, stderr says why.

## 4. Conflicts (exit 2)

One `AskUserQuestion` with the conflicted files in the question:

- **Rozwiążę i pokażę** (Recommended): resolve each file, `git add`, `git
  rebase --continue`, one line per file on what changed. A semantic conflict
  in a file falls back to the per-file recommendation below.
- **Przerwij ten PR**: `git rebase --abort`, `git checkout -`, next PR.
- **Rozwiążesz sam**: one or two lines per file (which side, or the merge
  shape), wait; after his "gotowe" `git diff --check`, `git status`, continue.

Then `git push --force-with-lease`, `gh pr edit <n> --remove-label run_e2e`,
`gh pr edit <n> --add-label run_e2e`.

## 5. Finish

Check out the branch Greg started on. One summary: rebased + pushed + e2e
retriggered, aborted (why); no git output recap. Unattended `workctl` tab: the
same summary as the P10 mail (`../g-pr-common/PRIMITIVES.md`), subject `PR
#<n>: rebased, e2e retriggered`.

## `run_e2e`

Remove-then-add guarantees a `labeled` event. A repo without the label makes
`--remove-label` fail: not fatal, report "rebased + pushed; no run_e2e label,
skipped re-trigger" and move on.

## Never

Rebase a green mergeable PR · `git push --force` without lease · `git rebase
--skip` (drops a commit) · leave Greg on a different branch · lecture about git.
