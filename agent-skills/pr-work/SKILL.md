---
name: pr-work
description: Pick up a PR that needs work by reading the brief temp file that `bin/pr-watch-open` just wrote, then start fixing it in the current worktree. Triggered automatically when Greg clicks the SketchyBar pr_watch chip (the click handler sends `/pr-work` into the freshly-opened claude window), or manually when Greg types `/pr-work`, says "ogarnij tę prkę", "weź się za PR z notyfikacji", "co tam z tą prką", "work the PR". The brief lists failing CI checks and/or unresolved review threads — read it from the temp file (NOT from a prompt parameter) and act on it.
---

# pr-work

Read the PR brief that `bin/pr-watch-open` dropped in a temp file, then work the PR — you're already sitting in its worktree.

## Background

When Greg clicks the SketchyBar `pr_watch` chip on an actionable PR (failing CI or changes-requested), `bin/pr-watch-open`:

1. Generates a brief with `bin/pr-brief <num>` → writes it to **`/tmp/pr-brief-current.md`** (and a per-num copy `/tmp/pr-brief-<num>.md` for debugging).
2. Runs `work pr <num>` → creates/attaches the worktree and opens a `claude` window inside it.
3. Sends `/pr-work` into that claude window.

So when this skill fires, **your cwd is already the PR's worktree** and the brief is waiting in the temp file. The brief is NOT passed as a prompt parameter — you read it from disk.

## Steps

1. **Read the brief.**

   ```
   cat /tmp/pr-brief-current.md
   ```

   If that file is missing, fall back to the newest per-num brief:

   ```
   ls -t /tmp/pr-brief-*.md 2>/dev/null | head -1
   ```

   If there's no brief at all → tell Greg "Brak briefu PR w /tmp — kliknij chip pr_watch ponownie albo podaj numer PRki" and stop. Don't guess a PR number.

2. **Parse what it says.** The brief (Polish) contains:
   - PR number + title + URL.
   - `## Failujące checki CI` — list of failed checks with their detail URLs.
   - `## Nierozwiązane wątki review` — unresolved review threads as `[path:line] @author: body`.
   It may have one section, both, or (rarely) neither.

3. **Confirm the worktree** matches the PR before touching anything:

   ```
   git rev-parse --show-toplevel
   git branch --show-current
   ```

   The branch should match the PR's head branch. If you're clearly NOT in the right worktree (e.g. cwd is `$HOME`), say so and stop — don't fix the wrong branch.

4. **Do the work**, driven by which sections the brief has:
   - **Failing CI** → delegate to the **`g-pr-fix-checks`** skill (it knows the rebase / retrigger / log-reading flow). For genuine code failures, read the check logs (`gh run view` / the detail URL), find the cause, fix, run the relevant tests locally before claiming a fix.
   - **Unresolved review threads** → delegate to the **`g-pr-review`** skill (mine-PR / answer-reviewers branch). Address each thread in code, then draft an English reply per thread.
   - **Both** → handle CI first (a red PR can't merge anyway), then threads.

5. **Don't auto-commit / auto-push.** Follow the global commit gate (reviewr diff review → g-commit, Greg approves the commit). Pushing stays Greg's call.

## Notes

- This skill is the *entry point* — the actual fixing lives in `g-pr-fix-checks` and `g-pr-review`. Don't reimplement their logic; invoke them.
- The brief is a snapshot from click-time. If CI has since gone green or a thread got resolved, trust live `gh` state over the stale brief and say so.
- Manual use: Greg can type `/pr-work` in any worktree-attached claude window; it'll read whatever brief is current.
