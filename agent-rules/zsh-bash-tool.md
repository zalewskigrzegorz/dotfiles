---
description: The Bash tool runs zsh, not bash — `=word` expands, unquoted $vars do not word-split, `[]` and unmatched `*` glob; the cwd resets outside the project; plus pgrep self-match and the nushell side of tuios
alwaysApply: true
---

# The Bash Tool Is zsh: Traps

When a bash one-liner fails with `not found`, "no files" or `no matches found`, check these before suspecting the tool or the data.

1. **An unquoted `$var` is one word.** `oxfmt --check $files` passes the whole list as one path ("no files found"): use `${=files}` or pipe (`git diff --name-only | xargs pnpm exec oxfmt --check`). A command kept in a variable: guard denies it, use a function or `${=A}`.
2. **`[]`, `?` and an unmatched `*` are globs (`NOMATCH`).** `gh api … -f parents[]=$SHA` dies and `gh` gets an empty value: quote every `[]` and `?` arg (`-f 'parents[]'="$SHA"`, `-F 'ids[]=1'`; guard catches `gh api …?`). `ls *.zip` with no match dies: `*.zip(N)` or `find`, with `*` and `(N)` outside the quotes (`"$dir"/Epson_*.pdf(N)`, never `"…/Epson_*.pdf"(N)`); `dir/*/` likewise (`*/(N)`).
3. **An unquoted `&` or `;` in a URL ends the command**: `DATABASE_URL=postgres://…?a=1&b=2 pnpm prisma migrate deploy` ran half in the background and 13 migrations landed in the shared local `main`. A URL with `&`, `?` or `;` goes in single quotes in a `VAR=… cmd` prefix, an agent brief, and an env file sourced with `. file` (`DATABASE_URL='…'`). Before `migrate`, `reset` or `db push`, print the target host and database (no password) and check it (2f5fe621).
4. **`$?` after a pipe is the last command's**: read `${pipestatus[1]}`, and `test -s <file>` a file you produced before using it.
5. **`path`, `cdpath`, `fpath`, `manpath` are tied to arrays**: `read … path` overwrote `PATH`. Never as names in `read`, `for`, assignments: `app`, `bin`, `p`.
6. **macOS userland is BSD**: `sed` doesn't expand `\t`/`\n` in the replacement, `awk` has no `match(s, re, arr)` or `gensub` (use `perl -pe`, `$'\t'`, `python3 -I`, `rg -o -r`; `git apply --check` a generated patch). `stat` takes `-f`, not `-c`; `ps etime` is `[[dd-]hh:]mm:ss`. `git rev-parse --short` takes one rev: two give exit 128 after a good push.
7. **`$var:x` is a zsh modifier** (`:t :a :h :r :e …`): write `${B}:path` (guard denies the bare form). Guard also denies `echo ===`, `echo "$x" | jq` and a `cat` with no input, each with its fix.

## cwd: the next call may not run where you think

The cwd persists only inside the session's project directory; a `cd` outside it is undone after the call.

- **Task in a worktree that is not the session's cwd** (cwd `~`, or a toplevel not matching the task's repo/branch) → first call `cd <wt> && git rev-parse --show-toplevel` (`~/Code/tree/wt-<repo>/<branch>`), then every call starts with `cd <wt> &&` or uses absolute paths. Never run a command bare "to check" and again with `cd` (36b5e3cc).
- **Scratch logs go under an absolute path** (the scratchpad), never `../..`-relative.
- **Don't allowlist the `cd <abs> && …` shapes**: a symptom, not a command.

## Wait loops and CI waits

Guard denies the bad loops (`pgrep -f` self-match, `sleep` loops around `gh pr|run`, `gh run download` without `-D`, `bin/gh-run-wait`) and names the replacement. Beyond that:

- Every wait loop gets a `timeout` and exits on the first actionable state; a multi-line loop goes into a `#!/bin/bash` file in the scratchpad. A run over ~10 min goes through `Monitor`, ETA in one line at the start.
- `gh run watch` exits 1 on wifi loss too: check `gh run view <id> --json status,conclusion` before reporting a failure. A label-reading required check that stayed red is re-evaluated by removing and re-adding the label. Work e2e traps: `~/.claude/rules/work-ci-and-rebase.md`.
- **All checks of a PR → `gh-pr-checks-wait <pr>`** in the background, no `>` redirect (it prints `pass/fail/pending` each minute; `gh pr checks --watch` prints nothing without a TTY).
- **Waiting for a human is not a loop**: a merge, approval or reply ends the turn with one line ("powiedz zmergowane") or a popup on a real fork. Loops are for machine state: CI, deploys, builds.

## The other side of tuios is nushell

- **Steps Greg runs himself in a tuios window are nushell**, not bash ("komenda z 2 nie działa, mam nushell"). Secrets via `$env.PGPASSWORD = (input -s "hasło: ")`, cleared with `hide-env PGPASSWORD`. One numbered step per line, after one sentence on why the step needs him.
- **Text sent to a window** (`tuios send-text`, `workctl` bootstrap) is parsed by nushell: `&&`, `||`, `2>/dev/null`, `$(…)` fail (`nu::parser::shell_andand`). Wrap POSIX as `sh -c '…'` or write nu with `;`.
- **A TTY prompt** (`read -s`, pinentry, nushell `input -s`) is tested with `pty-run --input secret -- <cmd>` (prints transcript and `exit=<code>`; `--timeout SEC`, default 30, exit 124), never an inline pty script.
