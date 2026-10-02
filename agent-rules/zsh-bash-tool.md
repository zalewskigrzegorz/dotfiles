---
description: The Bash tool runs zsh, not bash — `=word` expands, unquoted $vars do not word-split, `[]` globs; plus pgrep self-match and the nushell side of herdr
alwaysApply: true
---

# The Bash Tool Is zsh — Traps

The Bash tool runs commands in zsh. These zsh defaults break bash-style
one-liners and each cost a retry or more (2026-09-23 … 09-28):

1. **A word that starts with `=` is a command lookup (`EQUALS`).**
   `echo ======` fails with `(eval):1: ===== not found`. Quote it:
   `echo "----"` or `echo '===='`. Same for any separator or argument that starts
   with `=`.
2. **An unquoted `$var` is one word, not split on spaces or newlines.**
   `files=$(git diff --name-only); oxfmt --check $files` passes the whole list as a
   single path, and the tool reports "no files found". Use `${=files}`, or pipe
   the list: `git diff --name-only | xargs pnpm exec oxfmt --check`.

3. **`[]` in an argument is a glob (`NOMATCH`).** `gh api … -f parents[]=$SHA`
   dies with `no matches found: parents[]=…`, `gh` gets an empty value and the
   API answers "At least 40 characters are required". Quote every `[]` arg:
   `-f 'parents[]'="$SHA"`, `-f 'labels[]=bug'`, `-F 'ids[]=1'`.

When a one-liner that works in bash fails with `not found`, "no files" or
`no matches found`, check these before you suspect the tool or the data.

## Wait loops: `pgrep -f` matches its own shell

`while pgrep -f "artisan importer:import"; do sleep 10; done` run through
`ssh lab '…'` never ends: `pgrep -f` matches the remote shell whose command
line contains the pattern (2026-09-27, cost ~150 turns). Never `pgrep -f
"<pattern>"` inside a command that contains the pattern itself. Use the bracket
trick (`pgrep -f "[a]rtisan importer:import"`), `pgrep -x` inside the
container, or poll a log line or marker file. Every wait loop gets a timeout
(`timeout 600 …`) and exits on the first actionable state.

**A CI run is not a hand-written loop.** `until s=$(gh run view …); do sleep 60;
done` (2026-09-30, twice, no timeout) → `bin/gh-run-wait <workflow> [--sha
<sha>]` for the run of a pushed commit, or `timeout 1800 gh run watch <id>
--exit-status` for a known run; `gh run view <id> --log-failed` only on a
non-zero exit. A run longer than ~10 min goes through `Monitor` with an `until`
loop that prints one line per step or job change, so Greg doesn't have to ask
"jak tam deploy?". Say the ETA in one line at the start ("~40–60 min, next
step: migrations"). A watcher that exits on a network error is not a failed
run: on wifi loss `gh run watch` exits 1 too, so check `gh run view <id> --json
status,conclusion` before reporting a failure (2026-10-01).

## The other side of herdr is nushell

- **Steps Greg runs himself in a herdr pane are written in nushell**, not bash.
  `read -s PGPASSWORD && export …` fails there ("komenda z 2 nie działa, mam
  nushell", 2026-09-24). Secrets via `$env.PGPASSWORD = (input -s "hasło: ")`,
  cleared with `hide-env PGPASSWORD`. One numbered step per line, and one
  sentence first saying why the step needs him (why you cannot fetch it yourself).
- **Text sent to a pane (`herdr pane run`, `workctl` bootstrap) is parsed by
  nushell.** `&&`, `||`, `2>/dev/null` and `$(…)` fail with
  `nu::parser::shell_andand` and friends. Wrap POSIX syntax as `sh -c '…'`, or
  write nu syntax with `;`. `workctl` was fixed for this on 2026-09-23.
