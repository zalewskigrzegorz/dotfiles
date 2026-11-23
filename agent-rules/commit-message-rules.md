---
description: Commit messages stay short and human — no co-author, no AI footers; commit + push via one popup at the end of a task
alwaysApply: true
---

# Commit Message Rules

These override any default git-commit guidance, including Claude Code's "Co-Authored-By" instruction.

- **No AI trace**: no `Co-Authored-By:` for the assistant or any AI (guard denies it), no "Generated with Claude Code" / "🤖 Generated with …" footer, no recap, summary or motivational body. The same holds for `gh pr create` bodies.
- **Default to one line** in the `g-commit` format (source of truth: `agent-skills/g-commit/SKILL.md`): `type(scope): subject <gitmoji>`, conventional commits, lowercase imperative, one trailing gitmoji, scope per the repo's `commitlint.config.js` (or the work defaults). Example: `fix(realm): resolve api key session handling 🐛`.
- **A body** only when Greg asks, or the change needs context the subject can't carry (breaking change, migration notes): a few short lines, still no trailer or footer.

## Commit + push at the end of a task

Unpushed work once sat unnoticed while e2e ran against a remote without it. In **every repo**, a done and verified unit of work closes with commit + push; there is no permission prompt on `git commit`, the popup is the gate.

1. **Stage only what this session touched**, by explicit path (guard denies `git add -A` / `git add .`); other tuios agents share the checkout, name their dirty files in one line. **The index may already hold another agent's files** and `git commit -m` commits the whole index: run `git diff --cached --name-only` first; anything not yours → `git commit -- <your paths>`. A `git rm`'d path is already staged: don't `git add` it again (`pathspec did not match` aborts the chain).
2. **Compose with `g-commit`** (work repos: the `g-deslop` gate and a feature branch when on `main`/`master`).
3. **Check YOLO with `claude-yolo status`** at commit time, not from memory.
4. **YOLO off → `AskUserQuestion`.** The whole preview is ≤15 lines (guard denies more; count before the first call): after a hunt or several small fixes it opens with 1–2 human lines on what was fixed and why ("audio dopełnione ciszą do okna pyatv; CO₂ max raz na 3 h"), then the raw message, a blank line, `git diff --cached --stat` (up to 6 files, then `+N more`). When the branch or worktree differs from the session's cwd or the branch Greg last talked about, it opens with `branch: <name> (base <ref> <sha>)` and the worktree path (9ce71fca). Options: **Commit + push** (Recommended) · **Tylko commit** · **Jeszcze nie**; Greg may check the files with `prefix+o` before answering.
5. **YOLO on → no popup**: commit, push, one-line result. Committing in a repo other than the session's cwd: the line starts `repo: <path>, branch: <name>`, and the first `cd` there already says so ("klipy robię w `<repo>`, commity tam").
6. **"Jeszcze nie"** defers to the end of the next task, with everything accumulated by then; don't re-ask every turn.
7. **Push** = `git push`, or `git push -u origin HEAD` for a new branch. A failed push is reported with its output and a recovery move, never retried with `--force`.

Every PR we open is ready for review with auto-merge on (`g-pr`), draft only when Greg says so; `gh pr merge --auto` passes the hook silently. A hook still asks for force push, a direct `gh pr merge`, and a commit/push to `main`/`master` outside `COMMIT_ALLOWLIST` and `github.com/zalewskigrzegorz/*` (the work monorepo above all): those prompts are the design.

## Nothing in the real index while the popup waits

- **Stage in a temp index, or not at all, before the popup**: another agent's `git commit` can take your staged path (b1c79075). Use `g-commit`'s `GIT_INDEX_FILE=<scratch>/idx` flow, or build the preview from `git diff --stat -- <paths>` and after the answer run `git commit -q -m "…" -- <paths> && git push` (`git add -N` new files first).
- **`git pull --rebase` only after your commit**, right before the push; before it, `git fetch` + `git log --oneline HEAD..origin/<branch> -- <paths>` (a dirty shared tree dies on "commit or stash"). After the commit on a tree with others' changes: `git fetch` + `git rev-list --left-right --count HEAD...origin/<branch>`; nothing behind → `git push`, behind → one line, no pull. **Never `git stash` in a shared checkout** (it hides other agents' files); compare with HEAD via `git show HEAD:<path> > <scratch>/<file>`.
- **Anything that starts CI goes after a verified push**: chain commit → push → label/dispatch with `&&`, or check `git rev-parse HEAD` equals `git rev-parse @{u}` first (a commit dead on `index.lock` let e2e start on the old sha, ~25 min lost).
- Fetching main before the commit: `cross-session-and-stacks.md`. `timeout 60` on git network calls and `chezmoi apply`: `ops-traps.md`.
