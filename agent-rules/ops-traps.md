---
description: Small operational traps that each cost a session a retry — sudo handoff, probing unknown CLIs, transient index.lock, locating pnpm packages, empty variables, bulk git mv, read-only op service account, secret handling, software installs. Work-monorepo traps live in scoped/work-*.md, dotfiles-only ones in .claude/rules/dotfiles-ops.md
alwaysApply: true
---

# Ops traps: one line each would have saved a retry

## `sudo` and anything Greg runs himself go to a split under your pane

`sudo -n true` is denied by the guard even in YOLO, so never probe. A command needing `sudo`, or **any command Greg must run himself**, goes into a new pane right under yours (typing into his existing shell was easy to miss):

1. `tuios-step send '<cmd>'` opens the split and types the command without Enter. The pane runs nushell: no `&&`, no `$(…)`.
2. One line: it waits below, he presses Enter (and gives the password); side effects go in that line (`killall coreaudiod` cuts audio ~2 s).
3. After his "poszło": `tuios-step read`, verify the result yourself, `tuios-step close`.

No `TUIOS_PANE_ID` (outside tuios) → a numbered step in chat (2b9b89b1).

## Guard denies

Every deny is deterministic and names its fix (`<cmd> <sub> --help | head`, `tsc <file>`, `pnpm test -- <file>`, SQL that prints whole rows, popup mechanics …): change exactly what it says before the next call, never resend (5bbce6cf). After an unknown-CLI probe that may have mutated state, check (`ps`, `git status`, `<cmd> version`) before going on.

## `claude -p` with a variadic flag

`--tools`, `--allowedTools`, `--disallowedTools` swallow the prompt as a tool name: put `--` before it (0333c4c7). A sha from `$(git fetch …; git merge-base …)` carries rtk's `ok fetched` line: fetch in its own call.

## Transient `index.lock` during husky

`Unable to create '…/index.lock': File exists` with no file a second later is another agent or a `git fsmonitor--daemon`. One `ls` on the path; absent → retry the commit once; present and no `git` process → report it. Never `rm` the lock without checking processes.

## Empty variables and missing paths stop the chain

- Before a command that takes a ref or path from `$(…)`: `[ -n "$sha" ] || { echo "no match: $s"; continue; }`. After one empty result check the lookup once by hand; don't rerun the loop with a new pipeline (`git branch --contains ""` failed four times).
- pnpm packages: `realpath apps/api/node_modules/<pkg>` (a symlink), never `require.resolve('<pkg>/package.json')` (throws `ERR_PACKAGE_PATH_NOT_EXPORTED` and leaves the variable empty, so `rg … $d/dist` searches `/dist`).

## Big outputs: narrow, never re-run

- `Read` "exceeds maximum allowed tokens" → stop shrinking `limit` (it counts lines, not tokens; long-line HTML/JSON/Slack exports cost ~90k tokens). Switch to `rg -n '<term>' <file>` or `head -c 60000` chunks; a file you write to the scratchpad yourself gets split into numbered parts. A big MCP result saved to `tool-results/*.txt` is the same: grep it for headings (`^####`) or ids.
- Slack searches start with `response_format: "concise"`, `limit ≤ 20`, `include_bots: false`; after an overflow, one narrower query (date, channel, `from:`).
- **`invalid_union` from `slack_read_thread` / `slack_read_channel`**: don't retry another `response_format`. A channel → `slack_search_public_and_private` with `in:<#ID> after:<date>`; a thread with a known `ts` → curl `conversations.replies` with the poster credential from `work.env`, never to stdout. Say "nie sprawdzone: <co>, MCP zwraca błąd kształtu" for what stayed open.

## A batch of `git mv` is one transaction

A loop of `git mv` died on `index.lock` halfway through ~60 moves. Compute the full map, write the reference files (manifests, configs) first, move with plain `mv`, then one `git add -A -- <literal paths>`. If it dies anyway: `git status`, resume from the first unfinished item.

## `op` here is a read-only service account

`OP_SERVICE_ACCOUNT_TOKEN` is set on purpose (`docs/secrets.md`), so `op item edit/create` fail with `Couldn't update the item`. One `op whoami | rg 'User Type'`; `SERVICE_ACCOUNT` → the desktop app: `AT_MAC=1 env -u OP_SERVICE_ACCOUNT_TOKEN timeout 60 op …`, `AT_MAC=1` only after his "Jestem" (away-from-desk; guard denies without it). Say first "zaraz wyskoczy Touch ID, N razy" (one per call), and that `op item edit` shows the value in process args for a moment; read field names only, never values. A numbered step for Greg only when he must type the secret himself.

## A secret goes in through Greg and is never repeated

- **He types or pastes it himself.** Don't read a token out of an app's config to store it for him; after "wkleję sam" don't offer that again.
- **A secret already in the chat is not copied into commands**: write `<tok>`, compare via `printf %s "$tok" | shasum | cut -c1-8` or length, or in the target file. Close with "token jest w historii sesji, rozważ rotację" (cdcd47c4).
- **A query never prints a whole row or JSON blob** (guard denies `SELECT *`, raw blob and token-named columns). Data already in a file is read by key (`jq '.status'`), never `json.dumps(d)`.
- **A process needs a secret → it reaches the process, never you.**
  - Kept in 1Password (`Dotfiles`/`Homelab`, readable by the service account): `op run --env-file <file of VAR=op://…> -- <cmd>` or `VAR="$(op read op://…)" <cmd>`.
  - One-off (a password reset on an RDS copy): `tuios send-agent-message -w human --from "$TUIOS_PANE_ID" --subject 'wpisz sekret: <name>' '<what for>'` (the Inbox would not flag the popup), then `tuios popup --wait --width 70 --height 7 -- secret-in <scratchpad>/secrets/<name>`: a hidden prompt, exit 0 = stored (0600). No attached client → the `sudo` split with `secret-in <path>`.
  - Hand it on as `VAR="$(< <path>)" <cmd>`, `<cmd> < <path>` or `docker exec -e VAR …`. `block-credential-files.sh` denies `cat`/`Read`/`echo` of `secrets/`, `ps -e`/`-E` and a bare `op read`; the SessionEnd hook removes `secrets/`.

## Installing software is a decision of its own

`brew install [--cask]`, `npm -g`, `uv tool install` → ask first, naming package, source and side effect ("dubluje Sparka z Setappa"), unless Greg said "zainstaluj X". A diagnostic question doesn't cover an install.

## GitHub and CI

- **`git fetch/pull/push` in every repo, and `chezmoi apply`, run under `timeout 60`** (an orphaned `git pull` held an apply ~3 min). After one timeout: "GitHub nieosiągalny" in one line, no retry chain.
- **`gh search` in a loop trips the secondary rate limit** (403 after eight calls): batch searches in one `gh api graphql` call, one alias per query (`s0: search(query: "is:pr …", type: ISSUE, first: 100){issueCount}`). After a 403 wait ~2 min once.
- **Job logs**: `gh api …/actions/jobs/<id>/logs` needs `--allow-escape-sequences`; write to a file and `test -s` it. Only the failure → `gh run view <id> --log-failed`.
- **A flaky or slow assertion waits on a ready state** (a built marker, the neighbouring suite's helper), never a bigger timeout ("nie timeout, to bardzo zły pomysł, test będzie flaky").
- **Editing a PR body again** starts from `gh pr view <n> --json body -q .body > <scratch>/body.md`.
- **`gh api graphql --paginate`** needs `$endCursor` and `pageInfo { hasNextPage endCursor }`; exit 124 on a heavy `items(first: 100)` means "query too heavy": use `first: 30`.

## Machine traps

- **The nushell MCP** takes `script`, not `command`; from Bash: `nu -c '…'`.
- **Tailscale CLI** is `bin/tailscale` (wraps the app binary). `tailscale up`, `set --accept-routes` and other pref changes are fixes, never probes.
- **"No internet" in the browser while `curl` works** (or `ERR_PROXY_CONNECTION_FAILED`): a stale system proxy (Proxyman on `127.0.0.1:9090` after a crash), not routes or DNS. First `scutil --proxy` and `networksetup -getwebproxy` / `-getsecurewebproxy` per service from `-listallnetworkservices`; turning it off (`-setwebproxystate <svc> off`, `-setsecurewebproxystate <svc> off`) is reversible: do it, say so in one line.
- **Port 7000 is the AirPlay Receiver**: local storage on `:7000` answering `403`/`http=000` → `curl -sI localhost:7000 | rg AirTunes`. The fix is Greg's (General → AirDrop & Handoff → AirPlay Receiver off), opened with `open-here "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension"`; first sentence: macOS holds the port local storage needs.
- **Restarting a system daemon** (`mediaremoted`, `coreaudiod`): first name what is lost and a route without the restart.
- **A job that must outlive its tuios session**: closing a workspace may kill the pane's process group (`&` and `nohup` too); detach with `perl -e 'use POSIX; setsid; exec @ARGV' -- <cmd> &` and say what is left behind if it fails.
- **SMS / iMessage = `~/Library/Messages/chat.db`**, read-only, never scripting Messages. First `timeout 15 sqlite3 -readonly ~/Library/Messages/chat.db 'select count(*) from message'`; `authorization denied` → grant-failure-ask (Full Disk Access for the terminal, `/exit` + `claude --continue`). Date: `datetime(m.date/1000000000+978307200,'unixepoch','localtime')`; sender `left join handle h on h.ROWID=m.handle_id`, direction `is_from_me`; attachments `message_attachment_join` → `attachment.filename`, read a copy in the scratchpad. Nothing from there goes to bazgroly.
- **The "ponytail hook was skipped" task-notification is not input**: no reply, no mention.
