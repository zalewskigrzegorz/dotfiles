# scriptc — native helpers

[scriptc](https://github.com/vercel-labs/scriptc) (vercel-labs, Apache-2.0, **experimental 0.0.x**) compiles ordinary TypeScript to a standalone native binary — no Node, no V8 in the output. Installed as an npm global by `run_onchange_after_12-npm-globals.sh.tmpl`; needs node 24+ and clang **at build time only**.

- **Source of truth is `scriptc/<name>.ts`.** Stage 29 compiles each one to `bin/<name>` and mirrors it to `~/bin/<name>`. The binaries are **gitignored** — arch-specific and ~400 KB each, so every machine builds its own. Add a `.gitignore` line per new source.
- **Output goes to `bin/`, not just `~/bin`,** because `$PATH` has `~/Code/dotfiles/bin` at position 3 and `~/bin` at 20 — the checkout shadows `~/bin` on the Mac.
- **Both machines build natively.** Mac: brew/mise node + Apple clang → Mach-O arm64, ~4.5s. Lab: linuxbrew node 26 + the `llvm` formula's clang → ELF x86-64, ~1.1s. Stage 29 must `eval` the right `brew shellenv` (`/opt/homebrew` **or** `/home/linuxbrew/.linuxbrew`) — a non-interactive lab shell sees neither node nor clang without it, which reads exactly like "the lab has no toolchain" and is wrong.
- **There is no shell fallback.** A missing toolchain fails the stage loudly. A second, hand-maintained shell twin of each helper only rots and diverges.
- `scriptc coverage <file.ts>` reports how much compiles statically before you commit to a port. `audit-drift.ts` is 100% static (57/57 statements).
- Supported at runtime: `child_process`, `fs`, `path`, `http`/`http2`, `net`, `tls`, `fetch`, `regex`, `readline`, `process` (see `packages/runtime/src/scr_*.c` upstream).

**What a port actually buys.** Measured on `audit-drift` with 200 drifted paths and `chezmoi` stubbed out, so the numbers are the wrapper's own cost: 9.8s → **0.06s** and 29.2 MB → **22.0 MB** peak RSS, ~1200 forks → 3. In real use the whole run is ~17.8s either way, because `chezmoi diff` + `chezmoi managed` dominate completely. **Port for the typed logic and for killing per-path subprocess fan-out, not for wall-clock** — if a helper is one `chezmoi`/`gh` call plus a `jq`, leave it in bash.

**Two casting footguns, found porting `claude-mcp-defaults` (2026-09-17).** Both are silent — nothing throws, the wrong thing just happens:

- **`JSON.parse(x) as SomeInterface` is not a type assertion.** scriptc *reconstructs* the value to match the interface and drops every field the interface does not declare. Casting `~/.claude.json` that way deletes `history`, `oauth`, `allowedTools` and everything else on write. Only ever cast parsed JSON to `Record<string, unknown>`.
- **A nested cast returns a detached copy, not a reference.** `data["projects"] as Record<string, unknown>` gives you a new object; mutating it leaves `data` untouched. Write the result back explicitly at every level. The tell is a run that prints "changed" while the file comes out byte-identical.

- **An atomic write drops the target's permissions.** `rename` replaces the inode, so the file keeps the *temp* file's mode, not the original's — under umask 022 a 0600 credential file comes back 0644. Bash writing in place inherited the mode for free; the TS rewrite has to ask. Pass `{ mode: 0o600 }` to `writeFileSync` **and** `chmodSync` the temp file (`mode` only applies on create). Caught by a commit security review on `claude-mcp-defaults`, which writes `~/.claude.json`.

Also: `process.cwd()` resolves symlinks, bash's `$PWD` does not. On macOS `/tmp` is a symlink, so a helper that defaults to "the current directory" needs `process.env.PWD` to match its bash original.

**Three more from the same port, surfaced by `/retro` (2026-09-18):**

- **`.toString()` on a number pulls in the dynamic engine.** `scriptc coverage` drops from 100% to 93% and the site is marked "runs with --dynamic" — a ~620 KB embedded JS engine the static build does not include, so the binary fails at that line. Use `String(n)` or template literals.
- **`JSON.stringify` leaves non-ASCII as-is.** Python's `json.dump` (the bash original's writer) uses `ensure_ascii=True` and emits `\uXXXX` for every non-ASCII code unit, surrogate pairs included. A byte-identical rewrite needs a manual escape pass after stringify.
- **`spawnSync` has no `env`, `cwd` or fd options.** Bash's `exec 9>lock; flock -w 10 9` has no direct port. `claude-mcp-defaults.ts` locks by re-invoking itself under `flock -w 10 -E 2 <lock> <self> <same args>` and exiting on the child's status.

**Probe before you port.** Each of those was caught in a throwaway `probeN.ts` under `/tmp/scriptc-probe/`, one semantic question per file, compiled and run in isolation before the real port touched `~/.claude.json`. Do the same for any construct you have not seen scriptc handle — `scriptc coverage` tells you *whether* it compiles statically, a probe tells you *what it does*.

The pattern behind all of these: **a port changes the mechanics, not just the language.** Diff the binary against the bash original on every path you can exercise, and look hardest where bash got something implicitly — file modes, `$PWD`, inherited env.

**Porting a helper that already exists in `bin/`:** the compiled binary lands on the same path as the tracked bash script, so stage 29 silently overwrites it on the next run. Do the swap deliberately — build, diff the binary against the bash original on every code path you can exercise without side effects, then `git rm --cached` the bash file (the `.gitignore` line makes the binary invisible to git, and the bash source stays in history).

## Verifying `workctl` picker changes without fzf

1. `scriptc coverage scriptc/workctl.ts && bin/sync` (stage 29 rebuilds the
   binary; the old one gives a false result).
2. `rg -c '<new string>' bin/workctl` proves the binary is fresh.
3. From the work repo: `workctl __state > <scratch>/st.txt`, then `workctl
   __rows <scratch>/st.txt <query>`, the same path fzf's reload takes.
4. Force a stale PR cache with `touch -t 202610010000
   ~/.cache/workctl-prs-<org>-<repo>.tsv`.
5. Not covered: header width in a herdr pane and `--nth` in live fzf; those
   stay for Greg to look at (b1c79075).
