---
description: Commit messages stay short and human — no co-author, no AI footers; commit + push via one popup at the end of a task
alwaysApply: true
---

# Commit Message Rules

These rules override any default git-commit guidance baked into the assistant (including the "Co-Authored-By" instruction in Claude Code's system prompt).

## Hard rules

1. **Never add `Co-Authored-By:` trailers.** No `Co-Authored-By: Claude ...`, no `Co-Authored-By: <any AI>`, no co-author for the assistant at all. The user authors their own commits.
2. **Never add "Generated with Claude Code" / "🤖 Generated with ..." footers** to commits or PR bodies.
3. **Never add trailing summaries, motivational notes, or recap paragraphs** to the commit body. If the user wants a body, they will say so.
4. **Default to a single-line message** in the `g-commit` format: `type(scope): subject <gitmoji>`. Only add a body when the user explicitly asks for one or when the change genuinely needs explanation that does not fit in the subject.
5. The `g-commit` skill (`agent-skills/g-commit/SKILL.md`) is the source of truth for format: conventional commits, lowercase imperative subject, one trailing gitmoji, scope per repo's `commitlint.config.js` (or the work-repo defaults).
6. **Commit and push go through one popup at the end of a task** — see below. There is no permission prompt on `git commit` any more; the popup is the gate.

## Commit + push at the end of a task

Unpushed work used to sit unnoticed while e2e ran against a remote that did
not have it yet (Greg, 2026-09-24). So when a logical unit of work is done and
verified, close it with a commit and a push instead of leaving it for Greg.
This holds in **every repo**.

1. **Stage only what this session touched**, by explicit path. Never `git add
   -A` / `git add .` — other herdr agents share the checkout, and their dirty
   files stay out. Mention them in one line if there are any.
   **The index may already hold another agent's files**, and `git commit -m`
   commits the whole index: `scriptc/workctl.ts`, staged by someone else, rode
   along in a sketchybar commit (2026-10-19). Run `git diff --cached
   --name-only` before every commit; anything not yours → `git commit -- <your
   paths>`. A path removed with `git rm` is already staged, so don't `git add`
   it again (`pathspec did not match` aborts the whole chain).
2. **Compose the message with `g-commit`** (in work repos that includes the
   `g-deslop` gate and a feature branch when on `main`/`master`).
3. **Check YOLO:** `claude-yolo status`. Ask it at commit time, not from memory
   — Greg can switch it off mid-session.
4. **YOLO off → `AskUserQuestion`.** Preview = the raw commit message, a blank
   line, then `git diff --cached --stat` (max ~10 files, then `+N more`).
   Options: **Commit + push** (Recommended) · **Tylko commit** · **Jeszcze
   nie**. Greg may check the files with `prefix+o` before answering. When the
   branch or worktree differs from the session's cwd or from the branch Greg
   last talked about, the preview opens with `branch: <name> (base <ref>
   <sha>)` and the worktree path; without it a fix split off a review looked
   like a commit onto someone else's PR (9ce71fca).
5. **YOLO on → no popup.** Commit, push, report the result in one line. When
   the repo you committed in differs from the session's cwd, that line starts
   with `repo: <path>, branch: <name>`, and the first `cd` into that repo
   already says so ("klipy robię w `<repo>`, commity tam"). Greg had to ask "a
   gdzie to commitujesz?" (b0af38dc).
6. **"Jeszcze nie"** defers to the end of the next task, with everything
   accumulated by then. Do not re-ask every turn.
7. **Push** = `git push`, or `git push -u origin HEAD` for a new branch. A
   failed push (rejected, hook, no upstream) is reported with its output and a
   recovery move — never retried with `--force`.

A hook still asks for force push, `gh pr merge`, and a commit or push to
`main`/`master` in a repo where master is not the working branch (anything
outside `COMMIT_ALLOWLIST` and `github.com/zalewskigrzegorz/*` — the work
monorepo above all). Those prompts are the design.

## Nothing in the real index while the popup waits

- **Stage in a temp index, or not at all, before the popup.** `git add` into
  the shared index while Greg reads the popup lets another agent's `git
  commit` take your path: `717259e` (someone else's sketchybar commit) carried
  `scriptc/workctl.ts`, and the own commit then said "nothing to commit"
  (b1c79075). Use `g-commit`'s `GIT_INDEX_FILE=<scratch>/idx` flow, or build
  the preview from `git diff --stat -- <paths>` and after the answer run
  `git commit -q -m "…" -- <paths> && git push` (`git add -N` new files first).
- **`git pull --rebase` only after your commit**, right before the push. On a
  dirty shared tree it dies with "commit or stash"; before the commit use
  `git fetch` + `git log --oneline HEAD..origin/<branch> -- <paths>`, and
  don't repeat the pull after that error (28ca873d).
- **Anything that starts CI goes after a verified push.** Chain commit → push
  → label or dispatch with `&&`, or check `git rev-parse HEAD` equals
  `git rev-parse @{u}` first. A commit that died on `index.lock` still let a
  `run_e2e` label start e2e on the old sha, ~25 min lost (9adba92d).
- **In dotfiles, `git pull/push` and `chezmoi apply` run under `timeout 60`.**
  An orphaned `git pull` held an apply for ~3 min (56927b0a).

## What a commit looks like

```
fix(realm): resolve api key session handling 🐛
```

That's it. No second line, no trailer, no signature.

## When a body IS appropriate

Only when the user asks for one, OR when the change requires context the subject cannot carry (e.g. breaking change explanation, migration notes). In that case keep it to a few short lines — still no co-author, still no AI footer.

## PRs

Same rules apply to `gh pr create` bodies: no "🤖 Generated with Claude Code" line, no AI co-author, no auto-appended marketing.
