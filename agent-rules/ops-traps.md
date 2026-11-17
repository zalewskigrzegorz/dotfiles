---
description: Small operational traps that each cost a session a retry — sudo handoff, probing unknown CLIs, transient index.lock, locating pnpm packages, empty variables, bulk git mv, read-only op service account, secret handling, software installs. Work-monorepo traps live in scoped/work-*.md, dotfiles-only ones in .claude/rules/dotfiles-ops.md
alwaysApply: true
---

# Ops traps — one line each would have saved a retry

## `sudo` goes to a split under your pane, never a probe

`sudo -n true` is denied by the guard even in YOLO (2026-09-24), so probing is
pointless. A command that needs `sudo`, and **any command Greg must run
himself**, goes into a new pane right under yours, where he is looking. Typing
into his existing shell window was easy to miss (2026-10-27).

1. `tuios-step send '<cmd>'` opens the split, types the command without
   Enter and prints its id. The pane runs nushell, so it refuses `&&` and `$(…)`.
2. One line: it is waiting below, he presses Enter (and gives the password).
   Side effects (`killall coreaudiod` cuts audio for ~2 s) go in that line.
3. After his "poszło", `tuios-step read` shows the pane's tail. Verify the
   result yourself, then `tuios-step close`.

No `TUIOS_PANE_ID` (outside tuios) → a numbered step in chat. Greg: "tak masz
mi rozwiązywać odpalanie poleceń" (2b9b89b1, 2026-10-23).

## Unknown CLI

`guard` denies `<cmd> <sub> --help | head`. If a probe may have mutated state,
check (`ps`, `git status`, `<cmd> version`) before going on.

## A guard deny names its fix: apply it, never resend

Every deny is deterministic, so the same text fails the same way. One session
resent `git add -A && git commit` and `2>/dev/null` on `rg` twice in a row and
hit the popup checks five times (5bbce6cf). After a deny, change exactly what
the message says before the next call. Before a popup: no digit in
`question`, `header` ≤ 12 chars, no "Other". A digit is also `2FA`, `e2e`,
`1Password`, a PR number, a version, an hour, `cmd+shift+5`. Read the whole
`question`, not just the word you see (19 sessions).

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

## `Read` "exceeds maximum allowed tokens" → stop shrinking `limit`

`limit` counts lines, not tokens. On a flattened HTML, JSON or Slack export
with very long lines, three smaller `limit`s failed in a row and cost ~90k
tokens (2026-10-09). After the first error, switch to `rg -n '<term>' <file>`
or `head -c 60000` chunks; when you write such a file to the scratchpad
yourself, split it into numbered parts. A big MCP result saved to
`tool-results/*.txt` is the same case: `slack_read_file` on a scenarios doc
came back as 1.3 M chars (2026-10-14). Grep it for headings (`^####`) or ids
instead of reading it whole.

## `tsc <file>`, `pnpm test -- <file>`

Both denied by `guard` with the replacement (`tsc -p`, `vitest run`).

## A batch of `git mv` is one transaction

A loop of `git mv` plus manifest edits died on `index.lock` halfway through
~60 moves and left the repo half-moved (2026-10-02). Bulk move: compute the
full map, write the reference files (manifests, configs) before the first
move, move with plain `mv`, then one `git add -A -- <literal paths>`. If it
dies anyway: `git status`, resume from the first unfinished item.

## `op` here is a read-only service account

`OP_SERVICE_ACCOUNT_TOKEN` is set on purpose (headless `op`, `docs/secrets.md`),
so `op item edit` / `op item create` fail with `Couldn't update the item`.
One `op whoami | rg 'User Type'`; `SERVICE_ACCOUNT` → go through the desktop
app yourself: `AT_MAC=1 env -u OP_SERVICE_ACCOUNT_TOKEN timeout 60 op …`, the
`AT_MAC=1` only after his "Jestem" in a popup (guard denies it without) (`account
list`, `vault list`, `item get`, `item move` verified 2026-10-20, one Touch ID
per call). Say first "zaraz wyskoczy Touch ID, N razy", read field names only,
never values. A numbered step for Greg stays only when he must type the secret
himself (c333538c). Say up front that `op item edit` shows the value in the
process args for a moment.

## A secret goes in through Greg, and is never repeated

- **Greg types or pastes it himself.** Don't read a token out of an app's
  config to write it to 1Password for him; after "wkleję sam" don't offer that
  variant again (368db022).
- **A secret already in the chat is not copied into commands.** Write `<tok>`,
  compare with `printf %s "$tok" | shasum | cut -c1-8` or the length, or
  compare in the target file. A pasted Jam SQL token ended up literal in three
  commands, one of them visible in `ps` (cdcd47c4). Close with one line: "token
  jest w historii sesji, rozważ rotację".
- **A query never prints a whole row or JSON blob.** `guard` denies `SELECT *`,
  a raw `details`/`metadata`/`SpanAttributes` column and a token-named field;
  a raw `details` leaked a customer's billing-portal token (48258e8d). Data
  already in a file is read by key (`jq '.status'`), never `json.dumps(d)`.
- **A process needs a secret → it reaches the process, never you.** Two
  routes, by whether the secret outlives the task (2026-10-27):
  - **Kept in 1Password** (`Dotfiles`/`Homelab`, readable by the service
    account): `op run --env-file <file of VAR=op://…> -- <cmd>`, or
    `VAR="$(op read op://…)" <cmd>`. `op run` masks it in stdout.
  - **One-off** (a password reset on an RDS copy): first `tuios
    send-agent-message -w human --from "$TUIOS_PANE_ID" --subject 'wpisz
    sekret: <name>' '<what for>'` (the popup is busy time for tuios, so the
    Inbox would not flag it), then `tuios popup --wait --width
    70 --height 7 -- secret-in <scratchpad>/secrets/<name>`. A hidden prompt
    pops up over his screen, the popup closes itself, exit 0 = stored (0600).
    No popup (no attached client) → the split from the `sudo` section with
    `secret-in <path>`.
  - Hand it on as `VAR="$(< <path>)" <cmd>`, `<cmd> < <path>` or `docker exec
    -e VAR …` (name only, value from your env). `block-credential-files.sh`
    denies `cat`/`Read`/`echo` of `secrets/`, `ps -e`/`-E` and a bare `op
    read`. The SessionEnd hook `secrets-cleanup.sh` removes `secrets/`.

## Installing software is a decision of its own

`brew install [--cask]`, `npm -g`, `uv tool install` → ask first, naming the
package, its source and the side effect ("dubluje Sparka z Setappa"), unless
Greg said "zainstaluj X" himself. A diagnostic question doesn't cover an
install (30ce5f6a).

## `gh search` in a loop trips the secondary rate limit

Eight `gh search prs` calls in a row answered `HTTP 403: You have exceeded a
secondary rate limit` (28ca873d). Several searches go in one `gh api graphql`
call with one alias per query (`s0: search(query: "is:pr …", type: ISSUE,
first: 100){issueCount}`). After a 403, wait ~2 min once; don't retry in a loop.

## The nushell MCP takes `script`, not `command`

`mcp__nushell__exec` called with `command` fails on `missing field 'script'`
(3c700a19, 3e254d67). From the Bash tool: `nu -c '…'`.

## A big MCP search result: narrow it, never re-run it

Start Slack searches with `response_format: "concise"`, `limit ≤ 20`,
`include_bots: false` (an 88 KB result went out twice, aed1533e). `guard`
caps `mempalace_search` at `limit` 3. After "exceeds maximum allowed tokens",
`rg`/`jq` the saved `tool-results/*.txt` or send one narrower query (date,
channel, `from:`).

**`invalid_union` from `slack_read_thread` / `slack_read_channel`:** don't
retry with another `response_format`. A channel → `slack_search_public_and_private`
with `in:<#ID> after:<date>`. A thread with a known `ts` → curl
`conversations.replies` with the poster credential from `work.env`, never to
stdout. Say "nie sprawdzone: <co>, MCP zwraca błąd kształtu" for what stayed
open (585c8429, e0d05ff6).

## The Tailscale CLI is `bin/tailscale`

The app's CLI is not on PATH; `bin/tailscale` wraps
`/Applications/Tailscale.app/Contents/MacOS/Tailscale` (83a07dcc, 6f32e82c).
`tailscale up`, `set --accept-routes` and other pref changes are fixes, never
probes.

## "No internet" in the browser: read the error, then the proxy

`ERR_PROXY_CONNECTION_FAILED` on the screenshot, or `curl` working while the
browser fails, means a stale system proxy (Proxyman on `127.0.0.1:9090` left
on after a crash), not routes or DNS (`curl` ignores it). First `scutil
--proxy` and `networksetup -getwebproxy` / `-getsecurewebproxy` per service
from `-listallnetworkservices`, routes and DNS after. Turning it off
(`-setwebproxystate <svc> off`, `-setsecurewebproxystate <svc> off`) is
reversible: do it and say so in one line (83a07dcc).

## Port 7000 is the AirPlay Receiver

Local storage on `:7000` answering `403` or `http=000` →
`curl -sI localhost:7000 | rg AirTunes` (process `ControlCenter`). The fix is
Greg's: General → AirDrop & Handoff → AirPlay Receiver off, opened with
`open-here "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension"`.
The first sentence says why: macOS holds the port local storage needs
(c333538c).

## A job that must outlive its tuios session: `setsid`

On herdr, closing a workspace killed the pane's process group, `&` and `nohup`
included. tuios isn't verified to differ, so the rule stays: detach with `perl
-e 'use POSIX; setsid; exec @ARGV' -- <cmd> &` and say what is left behind if
it fails (dc819c48).

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
- **`gh api graphql --paginate`** needs the variable `$endCursor` and
  `pageInfo { hasNextPage endCursor }`. A heavy `items(first: 100)` ends in
  exit 124: use `first: 30`, read 124 as "query too heavy" (714ea30a).
- **`git fetch/pull/push` in every repo goes under `timeout 60`.** After one
  timeout "GitHub nieosiągalny" in one line, no retry chain (b5531ea1).
- **Restarting a system daemon** (`mediaremoted`, `coreaudiod`): first name
  what is lost and a route without the restart (bae51adc).

## The "ponytail hook was skipped" notice is not input

A task-notification saying the ponytail `UserPromptSubmit` hook was skipped
(`cc-plugin-sec-default` runs first) gets no reply and no mention. A first
reply spent two sentences on it and "Czekam na zadanie" (7c37679b).
