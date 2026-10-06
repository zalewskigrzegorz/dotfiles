---
description: Small operational traps that each cost a session a retry — sudo handoff, probing unknown CLIs, transient index.lock, locating pnpm packages, empty variables, bulk git mv, removing PR reviewers
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
