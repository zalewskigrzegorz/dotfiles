---
description: Small operational traps that each cost a session a retry — sudo handoff, probing unknown CLIs, transient index.lock, locating pnpm packages, empty variables, bulk git mv, removing PR reviewers, Slack token rotation, uvx cache lock, private overlay sync, e2e tsc, single spec runs
alwaysApply: true
---

# Ops traps — one line each would have saved a retry

## `sudo` goes to Greg's pane, never a probe

`sudo -n true` is denied by the guard even in YOLO (2026-09-24), so probing is
pointless. When a command needs `sudo`:

1. Type it into his shell pane with `herdr pane` (skill `herdr-orchestration`),
   **without Enter**.
2. Say in one line that it is waiting and that he presses Enter and gives the
   password.
3. If it has side effects (`killall coreaudiod` cuts audio for ~2 s), say so and
   ask for "poszło" after.

## Unknown CLI: no `<cmd> <sub> --help | head`

`collie update --help | head -30` started a real update (Collie has no
`--help`), and `head` closing the pipe left a half-built `web/dist-staging/`
(2026-09-29). On a CLI you have not used: read its source or docs first, or
probe only top-level `-h` / `--version` (`--dry-run` if documented). Never
pipe a subcommand into `head`. If a probe may have mutated state, check
(`ps`, `git status`, `<cmd> version`) before going on.

## Transient `index.lock` during husky

`Unable to create '…/index.lock': File exists` from a commit hook, with `ls`
showing no such file a second later, is another agent in the same worktree or a
`git fsmonitor--daemon` (3× on 2026-09-28). One `ls` on the path; if absent,
retry the commit once; if present and no `git` process is running, report it.
Never `rm` the lock without checking processes.

## pnpm: `realpath`, not `require.resolve('<pkg>/package.json')`

Many packages have `exports` without that subpath, so `require.resolve` throws
`ERR_PACKAGE_PATH_NOT_EXPORTED`, the path variable ends up empty and the next
`rg … $d/dist` runs against `/dist` (2026-09-29, 14× `realpath` later). Use
`realpath apps/api/node_modules/<pkg>` (pnpm's `node_modules/<pkg>` is a
symlink). Stop when a path variable is empty, before it reaches `rg`.

## An empty variable stops the chain

`sha=$(git log --grep …)` came back empty four times in a row, and `git branch
--contains "$sha"` failed with `malformed object name` each time; every retry
changed the lookup instead of stopping (2026-10-06). The empty `$d` above is
the same shape. Before a command that takes a ref or a path from `$(…)`:
`[ -n "$sha" ] || { echo "no match: $s"; continue; }`. After one empty result,
check the lookup once by hand; don't rerun the loop with a different pipeline.

## `pnpm patch-commit` rewrites more of the lockfile than the patch

After `pnpm patch-commit`, `pnpm-lock.yaml` also had a `(patch_hash=…)` peer
suffix on `@better-auth/oauth-provider`, which was not patched; undoing it took
~6 calls (2026-10-09). Right after it: `git diff --stat pnpm-lock.yaml
pnpm-workspace.yaml patches/`, keep only the patched package's entries and its
`patchedDependencies` line, and restore the rest from `git show HEAD:<file>`.

## `Read` "exceeds maximum allowed tokens" → stop shrinking `limit`

`limit` counts lines, not tokens. On a flattened HTML, JSON or Slack export
with very long lines, three smaller `limit`s failed in a row and cost ~90k
tokens (2026-10-09). After the first error, switch to `rg -n '<term>' <file>`
or `head -c 60000` chunks; when you write such a file to the scratchpad
yourself, split it into numbered parts. A big MCP result saved to
`tool-results/*.txt` is the same case: `slack_read_file` on a scenarios doc
came back as 1.3 M chars (2026-10-14). Grep it for headings (`^####`) or ids
instead of reading it whole.

## Slack poster token rotation: env var beats the file

After rotating `WORK_SLACK_POSTER_TOKEN` the first send failed on
`token_revoked`: sessions and shells started earlier still held the old token,
and the scripts read the env var before `work.env` (2026-10-13). Rotation =
update the `slack-poster-user-token` item **and** the line in the `WORK_ENV`
document (`bin/sync` restores `work.env` from that document, not from the
item). Test with `env -u WORK_SLACK_POSTER_TOKEN <script>`, and restart shells
and sessions opened before the rotation (`/exit`, `claude --continue`). The
token goes clipboard → consumer → `pbcopy < /dev/null`, never to stdout.

## A `uvx` MCP server locks the uv cache

Every running `uvx <server>` holds the lock on `~/.cache/uv`, so `uv cache
prune` in `disk-sweep` timed out with one lock per Claude session
(2026-10-13). An MCP server is installed with `uv tool install` in stage 26 and
started by its binary name, never through `uvx`. Diagnose with `ps -axo
pid,etime,command | rg '[u]vx '`; sessions started before the change keep the
lock until restarted.

## Private overlay edits: vault first, then `bin/sync`

A skill or rule from the `PRIVATE_AGENT_ASSETS_TAR` overlay lives in
1Password. `bin/sync` restores it from the vault, so a local edit vanishes
unless the tar was pushed first (`op document edit … --vault Dotfiles`, then
`op document get` to scratch and `cmp`). The push needs Greg's 1Password
approval; when he is away from the Mac, don't run `op` or `bin/sync`: leave
the `*.pending.tar` and end with "powiedz zatwierdzę". Don't re-fire the
approval prompt (2026-10-13, two `authorization timeout`s).

## Type-checking an e2e suite: `tsc -p`

`tsc <file>.ts` next to a `tsconfig.json` dies with `TS5112: tsconfig.json is
present but will not be loaded if files are specified on commandline`. Use
`pnpm exec tsc -p e2e/<suite>/tsconfig.json --noEmit`; not every suite has one,
so `test -f` first. No `--ignoreConfig`: it drops `paths` and the Playwright
types (2026-10-14).

## One spec file: `vitest run`, not `pnpm test --`

`pnpm test -- <file>` in an app runs the whole `nx` target (4 tasks, ~50 s) and
buries the file's result in the tail. For one file: `cd apps/<app> && pnpm exec
vitest run <file>`. The full target only before a PR (2026-10-14).

## A batch of `git mv` is one transaction

A Python loop of `git mv` plus manifest edits died on `index.lock` about
halfway through ~60 module moves. The manifest was not written yet, so the
repo sat half-moved and validation failed on ENOENT (2026-10-02). For a bulk
move: compute the full map first, write the reference files (manifests,
configs) before the first move, move with plain `mv` (no index), then one
`git add -A -- <literal paths>` at the end. If it dies anyway: `git status`,
then resume from the first unfinished item, not from zero.

## `gh api`: removing a requested reviewer

`DELETE …/pulls/<n>/requested_reviewers` wants both keys in the body;
`-f 'team_reviewers[]=<slug>'` alone answers `"reviewers" wasn't supplied`
(2026-10-02). Send JSON:
`printf '{"reviewers":[],"team_reviewers":["<slug>"]}' | gh api -X DELETE repos/<o>/<r>/pulls/<n>/requested_reviewers --input -`.

## Temporal specs are red in the sandbox by design

`libs/temporal-workflows/**/*.spec.ts` download Temporal's test server at
start, and the sandbox has no network: they fail with `Failed to start
ephemeral server: error sending request`. A full api `vitest` run where only
those files are red, on that message, is reported in one sentence ("tylko
temporal, brak sieci w sandboxie, CI to pokryje"). Don't hunt for a
regression and don't rerun (2026-10-12). Any other failure in those files is
a normal failure.
