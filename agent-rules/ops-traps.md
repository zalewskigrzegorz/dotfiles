---
description: Small operational traps that each cost a session a retry — sudo handoff, probing unknown CLIs, transient index.lock, locating pnpm packages, empty variables, bulk git mv, removing PR reviewers, Slack token rotation, uvx cache lock, private overlay sync, e2e tsc, single spec runs, read-only op service account, secret handling, software installs
alwaysApply: true
---

# Ops traps — one line each would have saved a retry

## `sudo` goes to Greg's pane, never a probe

`sudo -n true` is denied by the guard even in YOLO (2026-09-24), so probing is
pointless. When a command needs `sudo`:

1. Type it into his shell window with `tuios send-text` (skill `tuios-orchestration`),
   **without a trailing newline**, so no Enter.
2. Say in one line that it is waiting and that he presses Enter and gives the
   password.
3. If it has side effects (`killall coreaudiod` cuts audio for ~2 s), say so and
   ask for "poszło" after.

The same goes for **any command Greg must run himself**, not only `sudo`: find
the shell window (`tuios list-windows -s "$TUIOS_SESSION" --json`, the one whose `agent_state` is `none`;
`tuios-peek` to confirm an empty `❯`),
`tuios send-text -s "$TUIOS_SESSION" -w <window> '<cmd>'`, name the workspace in one line, verify the
result yourself after "poszło". Greg: "tak masz mi rozwiązywać odpalanie
poleceń" (2b9b89b1, 2026-10-23).

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

## `op` here is a read-only service account

`OP_SERVICE_ACCOUNT_TOKEN` is set on purpose (headless `op`, `docs/secrets.md`),
so `op item edit` / `op item create` fail with `Couldn't update the item`
(2× in a row, 2026-10-19). One `op whoami | rg 'User Type'`; `SERVICE_ACCOUNT`
→ go through the desktop app yourself: `env -u OP_SERVICE_ACCOUNT_TOKEN
timeout 60 op …` (`account list`, `vault list`, `item get`, `item move`
verified 2026-10-20, one Touch ID per call). Say first "zaraz wyskoczy Touch
ID, N razy", read field names only (`label`, `type`, set/empty), never values.
A numbered step for Greg stays only when he must type the secret himself
(c333538c: "a nie możesz tego zrobić, ja potwierdzę Touch ID"). Say up front
that `op item edit` shows the value in the process args for a moment.

## A secret goes in through Greg, and is never repeated

- **Greg types or pastes it himself.** Don't read a token out of an app's
  config to write it to 1Password for him; after "wkleję sam" don't offer that
  variant again (368db022).
- **A secret already in the chat is not copied into commands.** Write `<tok>`,
  compare with `printf %s "$tok" | shasum | cut -c1-8` or the length, or
  compare in the target file. A pasted Jam SQL token ended up literal in three
  commands, one of them visible in `ps` (cdcd47c4). Close with one line: "token
  jest w historii sesji, rozważ rotację".

## Installing software is a decision of its own

`brew install [--cask]`, `npm -g`, `uv tool install` → ask first, naming the
package, its source and the side effect ("dubluje Sparka z Setappa"), unless
Greg said "zainstaluj X" himself. A diagnostic question ("jaki mam plan") does
not cover an install; `brew install --cask readdle-spark` went in unasked next
to the Setapp copy (30ce5f6a).

## `/tui` switches every running Claude session at once

`/tui default` writes `tui` into `~/.claude/settings.json`, every open session
reloads it live, and each one dropped from the fullscreen renderer to an empty
normal screen: Greg saw nothing in any tab (28ca873d, 2026-10-21). The other
sessions then answer "Already using the default renderer", which is the shared
setting, not a sign they were untouched. Never run `/tui` or edit `tui` while
sessions are open. Test a renderer in one new session only:
`with-env {CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN: '1'} { claude }`. To recover,
set `tui` back in `~/.claude/settings.json`; sessions redraw on the next key.

The `env` block reloads live the same way. `CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN`
put there through `.chezmoitemplates/claude-settings.json` + `bin/sync` blanked
every open session within seconds (928081b1, 2026-10-21, reverted in 47a4241).
A renderer flag goes into the process env (`with-env` for one session, nushell
`env.nu` for new ones), never into settings.json. Removing a key from the
template does not remove it from the live file: `modify_settings.json.tmpl`
merges keys in, so `jq 'del(.env.X)'` the live file as well. The scroll jumps
came from Claude Code + herdr + Ghostty; on tuios they do not reproduce
(2.1.311, 2026-10-27), so don't blame upstream #34845 or reach for the alt
screen flag first.
The live-reload blanking is filed as anthropics/claude-code#104064. Blank
sessions do not come back after the revert: `/exit` + `claude --continue`.

## A cheap Haiku call from a script or hook

`claude -p --model claude-haiku-5-5 --no-session-persistence --strict-mcp-config
--tools "" --setting-sources "" --system-prompt "…" "<input>" </dev/null`, with
an env guard (`HD_TITLE_CHILD=1`) that your own hook checks first. No hooks,
plugins, MCP or CLAUDE.md load: ~600 tokens, ~2 s, $0.0002. `--bare` is not an
option here, it reads only `ANTHROPIC_API_KEY`, never the OAuth login. Haiku
sometimes reasons before the answer, so take the last line. Without
`</dev/null` it eats the stdin of a `while read` loop around it, and the loop
ran one item out of twelve (28ca873d).

## `gh search` in a loop trips the secondary rate limit

Eight `gh search prs` calls in a row answered `HTTP 403: You have exceeded a
secondary rate limit` (28ca873d). Several searches go in one `gh api graphql`
call with one alias per query (`s0: search(query: "is:pr …", type: ISSUE,
first: 100){issueCount}`). After a 403, wait ~2 min once; don't retry in a loop.

## The nushell MCP takes `script`, not `command`

`mcp__nushell__exec` called with `command` fails on `missing field 'script'`
(3c700a19, 3e254d67). From the Bash tool: `nu -c '…'`.

## A big MCP search result: narrow it, never re-run it

`slack_search_public_and_private` came back at 88 KB and the same query went
out again (aed1533e); `mempalace_search` with `limit=5` overflowed twice in a
row (3905c082). Start Slack searches with `response_format: "concise"`,
`limit ≤ 20`, `include_bots: false`; MemPalace with `limit=2`, or
`bin/mp-search` for a literal token. After "exceeds maximum allowed tokens",
`rg`/`jq` the saved `tool-results/*.txt` or send one narrower query (date,
channel, `from:`).

## The Tailscale CLI is `bin/tailscale`

The app's CLI is not on PATH; `bin/tailscale` wraps
`/Applications/Tailscale.app/Contents/MacOS/Tailscale` (83a07dcc, 6f32e82c).
`tailscale up`, `set --accept-routes` and other pref changes are fixes, never
probes.

## "No internet" in the browser: read the error, then the proxy

`ERR_PROXY_CONNECTION_FAILED` on the screenshot, or `curl` working while the
browser fails, means a stale system proxy (Proxyman on `127.0.0.1:9090` left
on after a crash), not routes or DNS; `curl` ignores the system proxy. First
`scutil --proxy` and `networksetup -getwebproxy <svc>` / `-getsecurewebproxy
<svc>` per service from `networksetup -listallnetworkservices`, routes and DNS
after. Turning it off (`-setwebproxystate <svc> off`, `-setsecurewebproxystate
<svc> off`) is reversible: do it and say so in one line (83a07dcc, 13 probes
on Tailscale first).

## Port 7000 is the AirPlay Receiver

Local storage on `:7000` answering `403` or `http=000` →
`curl -sI localhost:7000 | rg AirTunes` (process `ControlCenter`). The fix is
Greg's: General → AirDrop & Handoff → AirPlay Receiver off, opened with
`open-here "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension"`.
The first sentence says why: macOS holds the port local storage needs
(c333538c: "co?").

## A job that must outlive its tuios session: `setsid`

On herdr, `workspace close` killed the pane's process group, so `&` and `nohup`
died with it; tuios `kill-session` / `close-workspace` closing the pty is not
verified to differ, so the rule stays. Detach with `perl -e 'use POSIX; setsid; exec @ARGV' -- <cmd> &`
and say what is left behind if it fails (dc819c48).

## `bin/sync` on a held chezmoi lock

Another agent's `chezmoi apply` holds it. One `ps -axo pid,etime,command | rg
'[c]hezmoi'`; under ~2 min old → `timeout 180 sh -c 'while pgrep -x chezmoi
>/dev/null; do sleep 5; done'`, then `bin/sync` once. Older, or the wait timed
out → report pid and age. Never kill another agent's apply (f6d9d77e).

## Pushed dotfiles `master` from a worktree → fast-forward the main checkout

`bin/sync` and `~/bin` read `~/Code/dotfiles`. After `git push origin
HEAD:master` from a worktree: `git -C ~/Code/dotfiles fetch -q origin master
&& git -C ~/Code/dotfiles merge --ff-only origin/master`, only when that
checkout is clean and on `master`; otherwise one line (dc819c48).

## Before writing "X puts Y first on PATH"

Run `env PATH=<prefix>:/usr/bin:/bin command -v <tool>` and `<tool>
--version` once. An `ls` of the directory is not proof: `libexec/bin` held
only `python`, and two rules in a row named a wrong Python path (f6d9d77e).

## SMS and iMessage are `chat.db`, read-only

"SMS", "wiadomości", "iMessage" mean `~/Library/Messages/chat.db`, never
scripting Messages. First `timeout 15 sqlite3 -readonly
~/Library/Messages/chat.db 'select count(*) from message'`; `authorization
denied` → `grant-failure-ask` (Full Disk Access for the terminal, `/exit` +
`claude --continue`). Date: `datetime(m.date/1000000000+978307200,'unixepoch','localtime')`;
sender `left join handle h on h.ROWID=m.handle_id`, direction `is_from_me`;
attachments `message_attachment_join` → `attachment.filename`, read a copy in
the scratchpad. Personal data from there never goes to bazgroly (5666f824).

## CI and PR traps from 2026-10-23

- **Job logs:** `gh api …/actions/jobs/<id>/logs` refuses ANSI output without
  `--allow-escape-sequences`; write to a file and `test -s` it. Only the
  failure → `gh run view <id> --log-failed` (68513abd, 2 retries).
- **A flaky or slow assertion waits on a ready state**, a built marker or the
  helper the neighbouring suite uses, never on a bigger timeout: "nie timeout,
  to bardzo zły pomysł, test będzie flaky" (68513abd).
- **Editing a PR body again:** start from `gh pr view <n> --json body -q .body
  > <scratch>/body.md`; the file from `gh pr create` may be gone (03b98f19).

## The "ponytail hook was skipped" notice is not input

A task-notification saying the ponytail `UserPromptSubmit` hook was skipped
(`cc-plugin-sec-default` runs first) gets no reply and no mention. A first
reply spent two sentences on it and "Czekam na zadanie" (7c37679b).
