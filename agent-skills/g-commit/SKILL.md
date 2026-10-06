---
name: g-commit
description: Generates conventional commit messages from `git diff --cached` per commitlint and appends one gitmoji at the end of the subject, then commits and pushes after one confirmation popup (no popup in YOLO). In configured work repos it also runs the deslop gate and creates a feature branch off main/master. Use when the user asks to commit, write a commit message, or align with conventional commits / commitlint — and at the end of every finished task that left changes.
---

# g-commit

## When to use

- The user asks to commit, write a commit message, or align with commitlint / conventional commits.
- A logical unit of work is done and verified and left changes — close it here instead of leaving it for Greg (`agent-rules/commit-message-rules.md` → "Commit + push at the end of a task").

## Language

All **generated** text (commit message subject/body) must be **English**, even if the conversation is in another language.

## Gate (applies to every mode)

One `AskUserQuestion` popup approves both the commit and the push. There is no permission prompt on `git commit`; the popup is the review point. In YOLO (`claude-yolo status` prints `YOLO ON`) there is no popup at all. This skill never opens a PR — point at `g-pr` for that.

## Modes

The skill operates in one of two modes:

- **work mode** — deslop gate, branch guard on `main`/`master`, then gate → commit → push.
- **personal mode** — every other repo: gate → commit → push on the current branch (in dotfiles / home-lab that is `master`).

### Detecting the mode

The work-org identifier is **not** stored anywhere in this repository. It comes from the runtime environment, which the user's shell loads from a secret manager.

1. Read the work-org marker from `$WORK_COMPANY` (env var). If it's unset, empty, or whitespace → **personal mode** for this repo. Do not warn loudly; one short line is enough.
2. Read the repo's primary remote: `git remote get-url origin` (fallback to the first remote if `origin` is missing). Lowercase it.
3. If the remote URL contains the value of `$WORK_COMPANY` (case-insensitive substring) → **work mode**. Otherwise → **personal mode**.
4. Announce the mode in one short line before showing the message, e.g. `mode: work (matched remote)` or `mode: personal`. Do **not** echo the marker value or any other secret env contents back to the user — they're private.

If `$WORK_COMPANY` is available, `$WORK_MAIN_PROJECT` usually is too — you may use it (case-insensitive) as a hint when guessing scope, but never print it back.

## Steps

1. Run `git status`. Stage **only the files this session touched**, by explicit path — never `git add -A` / `git add .`, other agents share the checkout. Staged files this session touched are the commit. **Staged files from someone else stay out**: the index of a shared checkout can already hold another agent's hunks (2026-09-25: `scriptc/workctl.ts` and a `work.nu` hunk were staged by a sibling session). A plain `git commit` would sweep them in. Build a temporary index with only your paths and commit with it:
   ```bash
   GIT_INDEX_FILE=<scratchpad>/idx git read-tree HEAD
   GIT_INDEX_FILE=<scratchpad>/idx git add <your paths>
   GIT_INDEX_FILE=<scratchpad>/idx git commit -m "…"
   git reset -q            # resync the real index to the new HEAD; their staged hunks are re-staged by them
   ```
   Name the foreign dirty or staged files in one line. Nothing staged and nothing touched → stop and say so.
   Take the paths from `git status --short`, not from memory. A path removed with `git rm` is gone from disk and from the real index, so `git add <it>` there fails with `pathspec … did not match` and aborts the **whole** `add`; the gate then saw only the deletions (2026-10-06). In the temp index (read from `HEAD`) `git add -A -- <path>` stages the removal. Check `GIT_INDEX_FILE=<scratchpad>/idx git diff --cached --stat` before the popup, and keep mode detection in its own call so a `fatal:` doesn't get lost in the middle of the output.
2. Determine the mode (see above).
3. Analyze the staged diff: `git diff --cached`.
4. **Work mode, deslop gate (mandatory):** invoke `Skill(g-deslop)` on the staged diff before composing the message. Never `deslop` — that is the team's shorter prompt in the monorepo and it won once by name collision (2026-09-25), skipping the full gate. If the pass edits files, re-stage exactly those files and re-read `git diff --cached` — the message must describe the cleaned diff. The gate passes only by running the pass; "the diff already looks clean" is not a pass. Skipped only when the user explicitly says to skip it.
5. Build the commit message (rules below).
6. **Work mode, branch guard:** if `git rev-parse --abbrev-ref HEAD` is `main` or `master`, create a feature branch first:
   - `git checkout -b <type>/<scope>-<short-slug>` (e.g. `feat/<scope>-short-thing`).
   - Slug: lowercase, hyphens, short. Pick `type`/`scope` consistent with the commit you are about to make.
7. **Gate.** Run `claude-yolo status`.
   - `YOLO ON` → skip to step 8, no popup.
   - Otherwise → `AskUserQuestion`, header `Commit`. Put the **raw** commit message, a blank line, and `git diff --cached --stat` (max ~10 files, then `+N more`) in the `preview` of the first option — never in prose above the popup. If the branch or worktree differs from the session's cwd or the branch last discussed, the preview opens with `branch: <name> (base <ref> <sha>)` and the worktree path. Options: **Commit + push** (Recommended) · **Tylko commit** · **Jeszcze nie** (leave staged, ask again at the end of the next task).
8. **Commit** (see Execution), then **push** unless "Tylko commit" was picked: `git push`, or `git push -u origin HEAD` when the branch has no upstream.
9. Report in one line: short sha, branch, pushed or not. A failed push gets its output and a recovery move; never retry with `--force`.

## Commit message rules

1. If `commitlint.config.js` exists in the repo root, read it and honour its `type-enum`, `scope-enum`, and `scope-empty` rules. Do not invent values that would fail commitlint.
2. If there is no `commitlint.config.js`, use plain conventional-commit defaults (`feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`, `build`, `ci`, `revert`). Scope is optional; infer from changed paths if it's obvious, otherwise omit.
3. Format: `type(scope): subject` plus optional body/footer.
4. **Subject:** all lowercase, imperative mood ("add endpoint", not "added"), no period at the end, no leading capital, ~72 chars max **before** the gitmoji.
5. **Compound scopes** (e.g. `a,b`) are allowed only if the project's `scope-enum` lists that combination. Otherwise pick one scope or split the work — never invent scopes that fail commitlint.
6. When the user asks only for a message (not a commit), output **only** the raw message — no fences, no commentary around it.
7. Never append `Co-Authored-By:` trailers, "🤖 Generated with Claude Code" footers, or any other AI signature. The commit body — if any — only carries actual change context.

## Gitmoji (end of subject line)

Append **one** Unicode emoji at the **end** of the first line, after a space, based on the primary `type`:

| type           | emoji |
|----------------|-------|
| feat           | ✨    |
| fix            | 🐛    |
| docs           | 📝    |
| chore          | 🔧    |
| tests / test   | ✅    |
| hotfix         | 🚑    |
| refactor       | ♻️    |
| perf           | ⚡    |
| build          | 📦    |
| ci             | 👷    |
| revert         | ⏪    |

Example first line: `fix(api): resolve session handling 🐛`

If the repo's commitlint or CI rejects non-ASCII characters, say so and offer the same message **without** the emoji.

## Execution

```bash
git commit -m "<type>(<scope>): <subject> <emoji>" && git push
# or with body:
git commit -m "<type>(<scope>): <subject> <emoji>" -m "<body>" && git push
```

Commit and push are one `&&` chain, so a hook failure stops the push. **Never pipe `git commit` through `tail` or `head`**: the pipe swallows the exit code, and a push on the next line then ships whatever was already on the branch (2026-09-28: husky failed, nothing was committed, `git push` ran anyway). Check `git log -1` before reporting.

Never `--no-verify`, never `--force` push, never bypass hooks. If a commit or push hook fails, surface the failure and let the user decide.
