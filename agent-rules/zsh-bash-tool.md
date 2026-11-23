---
description: The Bash tool runs zsh, not bash — `=word` expands, unquoted $vars do not word-split, `[]` and unmatched `*` glob; the cwd resets outside the project; plus pgrep self-match and the nushell side of tuios
alwaysApply: true
---

# The Bash Tool Is zsh — Traps

The Bash tool runs commands in zsh. These zsh defaults break bash-style
one-liners and each cost a retry or more (2026-09-23 … 09-28):

1. **An unquoted `$var` is one word, not split on spaces or newlines.**
   `files=$(git diff --name-only); oxfmt --check $files` passes the whole list as a
   single path, and the tool reports "no files found". Use `${=files}`, or pipe
   the list: `git diff --name-only | xargs pnpm exec oxfmt --check`. A command
   kept in a variable is the same trap: `A="agent-browser --session-name x"; $A
   open …` fails with `command not found: agent-browser --session-name x`
   (2026-10-06). Use a function (`ab() { agent-browser --session-name x "$@"; }`)
   or `${=A}`.

2. **`[]` and an unmatched `*` are globs (`NOMATCH`).** `gh api … -f parents[]=$SHA`
   dies with `no matches found: parents[]=…`, `gh` gets an empty value and the
   API answers "At least 40 characters are required". `?` globs too:
   `gh api repos/…/contents/action.yml?ref=<sha>` dies on `no matches found`
   (37461a16). Quote every `[]` and `?` arg:
   `-f 'parents[]'="$SHA"`, `-f 'labels[]=bug'`, `-F 'ids[]=1'`. An unmatched
   `*.zip` is an error, not an empty list: `ls *.zip` dies with `no matches
   found: *.zip`. Use `*.zip(N)` for an empty list, or `find`. The `*` and
   `(N)` must sit outside the quotes: `"…/Skaner/Epson_*.pdf"(N)` is a literal
   and still dies (2026-10-09). Quote only the fixed prefix,
   `"$dir"/Epson_*.pdf(N)`, or use `find "$dir" -name 'Epson_*.pdf'`.
   `dir/*/` is the same glob and dies on a missing dir: `*/(N)` or `find`.
3. **An unquoted `&` or `;` in a URL ends the command.** `DATABASE_URL=postgres://…/db?a=1&b=2
   pnpm prisma migrate deploy` ran the first half in the background, and the
   migrate fell back to the default database: 13 migrations landed in the
   shared local `main` (2026-10-12). A URL with `&`, `?` or `;` always goes in
   single quotes, in a `VAR=… cmd` prefix and in agent briefs alike. Before
   `migrate`, `reset` or `db push`, print the target host and database (no
   password) and check it is the one you meant. **An env file sourced with
   `. file` is the same trap:** write `DATABASE_URL='…'` in single quotes there
   too, then print host and database from the loaded variable (2f5fe621).
4. **`$?` after a pipe is the last command's status.** `git apply x.patch |
   tail -5; echo "exit=$?"` printed `exit=0` for a patch that did not exist,
   because `tail` succeeded (2026-10-15). Read `${pipestatus[1]}`, and check a
   file you produced with `test -s <file>` before using it.
5. **`path`, `cdpath`, `fpath`, `manpath` are tied to arrays.** `read … path`
   overwrote `PATH` (11× `command not found: date`, 5f621afd). Not as names in
   `read`, `for`, assignments: use `app`, `bin`, `p`.
6. **macOS `sed` doesn't expand `\t` / `\n` in the replacement**, BSD `awk` has
   no `match(s, re, arr)` or `gensub`. Use `perl -pe`, `$'\t'`, `python3 -I` or
   `rg -o -r`, and `git apply --check` on a generated patch (07921d16). `stat`
   takes BSD `-f`, not GNU `-c`; `ps etime` is `[[dd-]hh:]mm:ss` (a5239d4c).
   `git rev-parse --short` takes one rev: two give exit 128 after a good push
   (2f5af49f, bb7f0a72).

The `guard` mod denies `echo ===` (`EQUALS`) and `echo "$x" | jq` with the fix.

When a one-liner that works in bash fails with `not found`, "no files" or
`no matches found`, check these before you suspect the tool or the data.

## cwd: the next call may not run where you think

The Bash cwd persists only inside the session's project directory. A `cd`
outside it is undone after the call ("Shell cwd was reset to …"), so a session
started in `~` or in another repo runs every later relative path from there
(five of 17 tool errors on 2026-10-04).

- **Task in a worktree that is not the session's cwd** → first call `cd <wt>
  && git rev-parse --show-toplevel`, then every call starts with `cd <wt> &&`
  or uses absolute paths. The trigger is a cwd of `~`, or a toplevel that does
  not match the branch or repo the task names; the path is
  `~/Code/tree/wt-<repo>/<branch>`. Never run a command bare first "to check"
  and then again with `cd` (~14 of 28 calls, 36b5e3cc).
- **Scratch logs go under an absolute path** (the session scratchpad), never
  `../..`-relative.
- **Don't allowlist the `cd <abs> && …` shapes** this produces. They are a
  symptom, not a command.

## Wait loops and CI waits

The `guard` mod denies `pgrep -f` without the bracket trick in a loop, a
`while`/`until` + `sleep` around `gh pr|run`, `gh run download` without `-D`,
and `bin/gh-run-wait`; each deny names the replacement. Beyond that: every wait
loop gets a `timeout` and exits on the first actionable state; a multi-line loop
goes into a `#!/bin/bash` file in the scratchpad. A run longer than ~10 min goes
through `Monitor`, with the ETA in one line at the start. `gh run watch` exits 1
on wifi loss too: check `gh run view <id> --json status,conclusion` before
reporting a failure. A required check that reads labels and stayed red is
re-evaluated by removing and re-adding the label. Work e2e (`run_e2e`,
`e2e-pr.yml`) traps: `~/.claude/rules/work-ci-and-rebase.md`.

**All checks of a PR → `gh-pr-checks-wait <pr>`** in the background, no `>`
redirect: it prints `pass/fail/pending` once a minute, so the tuios bg pane
shows progress. `gh pr checks --watch` prints nothing without a TTY until it
ends, and a redirect to a file leaves the pane empty too (2026-10-27).

**Waiting for a human is not a loop.** A merge, an approval or a reply ends
the turn with one line ("powiedz zmergowane"), or a popup if there is a real
fork. A background `until gh pr view <n> … MERGED; sleep 300` polled for hours
(2026-10-12). Loops are for machine state: CI, deploys, builds.

## The other side of tuios is nushell

- **Steps Greg runs himself in a tuios window are written in nushell**, not bash.
  `read -s PGPASSWORD && export …` fails there ("komenda z 2 nie działa, mam
  nushell", 2026-09-24). Secrets via `$env.PGPASSWORD = (input -s "hasło: ")`,
  cleared with `hide-env PGPASSWORD`. One numbered step per line, and one
  sentence first saying why the step needs him (why you cannot fetch it yourself).
- **Text sent to a window (`tuios send-text`, `workctl` bootstrap) is parsed by
  nushell.** `&&`, `||`, `2>/dev/null` and `$(…)` fail with
  `nu::parser::shell_andand` and friends. Wrap POSIX syntax as `sh -c '…'`, or
  write nu syntax with `;`. `workctl` was fixed for this on 2026-09-23.

## Testing a TTY prompt: `pty-run`, not an inline pty script

`read -s`, pinentry and nushell `input -s` need a controlling terminal, which
the Bash tool lacks. Use `pty-run --input secret -- <cmd>` (prints the
transcript and `exit=<code>`; `--timeout SEC`, default 30, exit 124). The pty
script was rewritten twice inline on 2026-10-08.

## More zsh: `$var:x` is a modifier

`git show $P:tooling/…` became `a942d18e36ooling/…` and `ambiguous argument`:
`:t` after a variable is zsh's "tail" modifier (also `:a :h :r :e :l :u :s :p`:
`$B:apps/…` lost its `a` to `:a`, 49842976). Always `${B}:path` or `"$B":path`.
