---
name: g-commit
description: Conventional commit message from `git diff --cached` per commitlint with one trailing gitmoji, then commit and push after one popup (none in YOLO). Work repos add the deslop gate and a feature branch off main/master. Use when the user asks to commit, write a commit message, or align with conventional commits / commitlint — and at the end of every finished task that left changes.
---

# g-commit

Policy (own paths only, the popup gate, YOLO, push, "Jeszcze nie"): the
"Commit + push at the end of a task" section of `commit-message-rules.md`.
This skill is the mechanics and the message format. It never opens a PR
(`g-pr`). Message text in **English**.

## Mode

- **work**: `$WORK_COMPANY` is set and the `origin` remote URL (fallback: first
  remote) contains it, case-insensitive. Deslop gate, branch guard, then
  gate → commit → push.
- **personal**: everything else (unset marker → personal, one short line).
  Gate → commit → push on the current branch (`master` in dotfiles/home-lab).

Announce `mode: work (matched remote)` or `mode: personal` in one line. Never
echo `$WORK_COMPANY`, `$WORK_MAIN_PROJECT` (a scope hint) or other secrets.
Detect the mode in its own call, so a `fatal:` isn't lost mid-output.

## Steps

1. **Stage your paths in a temp index**, from `git status --short`, never from
   memory. The real index may hold another agent's hunks:
   ```bash
   GIT_INDEX_FILE=<scratchpad>/idx git read-tree HEAD
   GIT_INDEX_FILE=<scratchpad>/idx git add <your paths>
   GIT_INDEX_FILE=<scratchpad>/idx git rm -q --cached -- <removed path>   # a removal; a move = rm --cached <old> + add <new>
   GIT_INDEX_FILE=<scratchpad>/idx git diff --cached --stat               # check before the popup
   ```
   A `git rm`'d path in the real index makes `git add <it>` fail with
   `pathspec … did not match` and abort the whole `add`. Name foreign dirty or
   staged files in one line. Nothing touched → stop and say so.
2. Read the staged diff.
3. **Work: deslop gate.** `Skill(g-deslop)` on the staged diff, never the
   team's `deslop` (it once won by name). Edited files are re-staged and the
   diff re-read; "looks clean" without running the pass is not a pass. Skip
   only on the user's word. Staged `docs/**.md` and a root `recheck.yaml` →
   `pnpm exec <docs-cli> recheck --config recheck.yaml <files> --format=table`
   (CLI from the root `package.json`); errors block the commit.
4. Build the message (below).
5. **Work: branch guard.** On `main`/`master` → `git checkout -b
   <type>/<scope>-<short-slug>` (lowercase, hyphens, matching the commit).
6. **Gate.** `claude-yolo status` in its own call (exit 1 = off, normal; never
   mid-`&&`). `YOLO ON` → no popup. Else `AskUserQuestion`, header `Commit`,
   preview per the rule (raw message, blank line, `--stat`; ≤15 lines with the
   `branch:` and human lines), options **Commit + push** (Recommended) ·
   **Tylko commit** · **Jeszcze nie**.
7. **Commit, then push** unless "Tylko commit":
   ```bash
   GIT_INDEX_FILE=<scratchpad>/idx git commit -m "<type>(<scope>): <subject> <emoji>" [-m "<body>"] && git push   # -u origin HEAD on a new branch
   git reset -q   # resync the real index to the new HEAD
   ```
   One `&&` chain so a hook failure stops the push. **Never pipe `git commit`
   through `tail`/`head`**: it swallows the exit code and the push ships the old
   branch. Check `git log -1` before reporting.
8. One line: short sha, branch, pushed or not. A failed push: its output and a
   recovery move.

A pre-commit hook rejection (lint-staged, stricter lint for new code) is fixed
in the code and committed once more; never re-run the identical commit. When
lint-staged uses a config the normal `--fix` doesn't, run that command on the
staged files before the gate. Never `--no-verify`, never `--force`.

## Message

1. `[ -f commitlint.config.js ] && echo commitlint || echo none` (a bare `ls`
   errors). Present → honour `type-enum`, `scope-enum`, `scope-empty` before
   the popup; in work mode check with `printf '%s' "$msg" | pnpm exec
   commitlint`. A `type-enum` without `ci`, `refactor`, `perf`, `build` makes a
   workflow change `chore` and a test change `tests`. A type changed after the
   popup costs one line ("type changed from X to Y, commitlint").
2. None → `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `build`,
   `ci`, `revert`; scope only when obvious from the paths.
3. `type(scope): subject`, subject lowercase, imperative, no period, ≤~72 chars
   before the gitmoji. Compound scopes (`a,b`) only if `scope-enum` lists them.
4. Single line by default; a body only on request or when the change needs it.
   No `Co-Authored-By`, no AI footer.
5. Message only (no commit) → output only the raw message, no fences.

## Gitmoji, one, at the end of the subject

feat ✨ · fix 🐛 · docs 📝 · chore 🔧 · tests/test ✅ · hotfix 🚑 · refactor ♻️
· perf ⚡ · build 📦 · ci 👷 · revert ⏪. Example: `fix(api): resolve session
handling 🐛`. Commitlint or CI rejects non-ASCII → say so, offer it without.
