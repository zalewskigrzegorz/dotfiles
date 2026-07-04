---
name: g-pr-fix-checks
description: Rebases open GitHub PRs failing checks or conflicting with base branch, force-pushes, retriggers run_e2e label. Use for "fix failing checks", "rebase the PR", "retrigger e2e", "my PRs are conflicting", or recovering PRs that went red after base branch moved.
---

# g-pr-fix-checks

## Purpose

Two cases this skill recovers:

1. `main` (or whichever base) got fixed after breaking unit tests / e2e / typescript — open PRs on top of it stay red until rebased.
2. `main` moved on and a PR now **conflicts** with it — GitHub flags it as not mergeable until rebased.

This skill discovers both kinds of PRs, lets the user pick which to fix, and runs the rebase + force-push + e2e re-trigger loop with **minimal AI involvement** — only stops to ask the user when there's a real decision (which PRs to touch, how to handle a conflict during rebase).

The skill is for the user's *own* open PRs across whichever GitHub repo the user is currently in. It does not pick repos for you — `cd` to the repo first.

## Prerequisites

Before running, verify:

- Current working directory is inside a git repo with a GitHub remote (`gh repo view` succeeds).
- `gh auth status` shows the user is logged in.
- Working tree is clean (`git status --porcelain` is empty). If dirty, ask the user whether to `git stash --include-untracked` or abort. Do **not** silently stash.

If any prereq fails, report exactly what's missing and stop — do not improvise.

## Workflow

Follow these steps in order. The scripts under `scripts/` do the deterministic work; your job is to present results, ask the user the few real decisions, and handle conflicts.

### 1. List the user's open PRs with check status

Run:

```bash
bash scripts/list_prs.sh
```

It outputs one line per open PR authored by the current user, ordered with the current branch's PR (if any) first:

```
<number>\t<state>\t<mergeable>\t<failed_checks>\t<headRefName>\t<baseRefName>\t<title>
```

Where:
- `state` is one of `FAILING`, `PENDING`, `PASSING`, `UNKNOWN` (CI checks rollup).
- `mergeable` is one of `MERGEABLE`, `CONFLICTING`, `UNKNOWN` (GitHub merge state vs base).
- `failed_checks` is a comma-separated list of failed check names (e.g. `build, e2e/login`), or `-` if none.

A PR is **actionable** for this skill if `state == FAILING` **or** `mergeable == CONFLICTING`. `UNKNOWN` mergeable on its own is not actionable (GitHub hasn't computed it yet); fall back to the check state.

### 2. Decide which PRs to update

- If **no** PRs are actionable → tell the user "no failing or conflicting PRs, nothing to do" and stop. Do not rebase green, mergeable PRs (the user explicitly does not want that).
- If exactly one PR is actionable and it's the current branch's PR → confirm with the user in one sentence (mention whether it's failing, conflicting, or both, and which checks failed if any), then proceed.
- Otherwise → present the actionable PRs as a short numbered list. One PR per line, in this shape:

  ```
  N) #<num>  <tag>  <branch>  ←  <title>
       failed: <check names>            # only if state == FAILING
  ```

  Where `<tag>` is one of `failing` / `conflicting` / `failing+conflicting`. Omit the `failed:` line entirely for purely-conflicting PRs. Then ask which to update: a single one, several (comma-separated), or `all`.

Keep the prompt terse. Do not lecture, do not list clean PRs, do not dump raw TSV.

### 3. For each selected PR, run the update

For each chosen PR number:

```bash
bash scripts/update_pr.sh <pr-number>
```

This script:

1. Remembers the current branch so you can return to it at the end.
2. Runs `gh pr checkout <number>` to switch to the PR branch.
3. Fetches the base branch and runs `git rebase origin/<base>`.
4. If the rebase succeeds → `git push --force-with-lease`, then toggles the `run_e2e` label (`gh pr edit <num> --remove-label run_e2e` then `--add-label run_e2e`), then exits with code 0.
5. If the rebase hits a conflict → it leaves the repo in mid-rebase state and exits with code 2. The list of conflicted files is printed.
6. Any other failure (no remote, push rejected, label missing) → exits with code 1 and the script's stderr explains what happened.

### 4. Handle conflicts (exit code 2)

When `update_pr.sh` exits with code 2, the working tree is mid-rebase with conflict markers. Ask the user:

> Conflicts in: `<file list>`. How do you want to handle this?
> **a)** I try to resolve them and show you the result before continuing
> **b)** Stop here — I'll run `git rebase --abort` and you handle this PR manually later
> **c)** You resolve them yourself; I'll give a quick recommendation per file first

Then:

- **a)** Read each conflicted file, attempt a resolution, run `git add <file>` + `git rebase --continue`. Before continuing show the user a brief summary of what you changed in each file (one line per file). If at any point a file's resolution isn't obvious (semantic conflict, both sides changed the same logic differently), fall back to option **c** for that file.
- **b)** Run `git rebase --abort`, return to the original branch (`git checkout -`), and move on to the next PR if any.
- **c)** For each conflicted file, give a one- or two-line recommendation (which side to prefer, or what the merge should look like) and wait. Once the user says they're done, verify with `git diff --check` and `git status`, then continue.

After conflicts are resolved and the rebase is complete, run the rest of the update manually:

```bash
git push --force-with-lease
gh pr edit <num> --remove-label run_e2e
gh pr edit <num> --add-label run_e2e
```

### 5. Return to where the user started

After the last selected PR is done (success or aborted), check out the branch the user was on when the skill started. If you stashed earlier, ask before popping.

### 6. Summarise

One short message at the end:

- which PRs were rebased + pushed + e2e-retriggered
- which were aborted (and why)
- nothing else — no recap of git output, no "let me know if you need more"

## Notes on the `run_e2e` label

This label is a work-repo convention: removing then re-adding it causes the workflow to fire again. The toggle pattern (remove → add) is intentional — adding a label that's already there is a no-op, so a remove-first-then-add guarantees an event. If a repo doesn't have a `run_e2e` label, `gh pr edit --remove-label run_e2e` will print a warning to stderr and exit non-zero. In that case, do **not** treat it as a hard failure for the whole skill — report it in the summary ("PR #1234 rebased + pushed; no run_e2e label in this repo, skipped re-trigger") and move on.

## Things to avoid

- Don't rebase a PR that's both green **and** mergeable. The user reaches for this skill specifically when base was broken or the PR conflicts; touching clean PRs is wasted CI and noise.
- Don't `git push --force` (without `--force-with-lease`). Lease protects against clobbering a teammate's push.
- Don't `git rebase --skip` on a conflict. Skipping silently drops the user's commit.
- Don't switch the user back to a different branch than they started on.
- Don't lecture about git or PR hygiene. The user knows.
