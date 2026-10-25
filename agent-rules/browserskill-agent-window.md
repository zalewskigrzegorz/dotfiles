---
description: BrowserSkill (`bsk`) drives Greg's real Comet profile — always in its own visible Agent Window, never by taking over his open tabs, and never by exporting cookies, passwords or tokens.
alwaysApply: true
---

# BrowserSkill (`bsk`) — Agent Window only

`bsk` (github.com/Tencent/BrowserSkill) drives Greg's **real, logged-in Comet
profile** from the CLI. That means his live sessions — bank, work SSO, GitHub,
Slack — are one command away. Treat it accordingly.

## Rules

1. **Own window, always.** Every task starts with `bsk session start`, which
   opens a separate **Agent Window**. All work (`navigate`, `click`, `fill`,
   `snapshot`) goes through `--session <id>` against that window. Greg watches
   the clicks happen there while he keeps using his own windows.
2. **Never touch his tabs unless he asks.** `bsk tab borrow` pulls one of Greg's
   own tabs into the agent session — only on an explicit request ("użyj mojej
   otwartej karty", "borrow the tab I have open"). When done, `bsk tab return`
   it. Do not borrow to save a login step.
3. **Never export credential material.** No dumping cookies, `localStorage`
   auth blobs, passwords, or bearer tokens to a file, a log, the transcript, or
   an outward-facing message — not via `bsk evaluate`, not via `get-html`, not
   via the profile directory on disk. Riding the existing session is the whole
   point; copying it out of the browser is not.
4. **Close the session.** `bsk session stop <id>` when the task ends, so the
   Agent Window disappears and nothing keeps a handle on his profile.
5. **Human-in-the-loop for human steps.** Captcha, 2FA, a login form, an
   irreversible confirm → `bsk request-help` and let Greg do it, then continue.
   Don't attempt to solve or bypass those.
6. **Read-only by default on his accounts.** Navigating and reading is fine;
   sending, posting, paying, deleting or changing account settings inside a
   logged-in session needs his go-ahead in the moment, even in YOLO mode.
   This is wired into permissions, not just trust: `session`/`window`/`navigate`/
   `snapshot`/`observe`/`screenshot`/`console`/`network`/`get-html`/`reload`/
   `wait-*`/`request-help` are pre-allowed, while **`click`, `fill`, `press`,
   `select`, `evaluate`, `tab borrow`, `record` prompt every time**. A prompt
   there is the design, not friction to route around.

## Three stacks while Browsentic is on trial

| Stack | Use it when | Why |
| --- | --- | --- |
| **`agent-browser`** (skill, Chrome/CDP, own profile) | **A quick shot Greg doesn't need to watch**: fetch a public page, scrape docs, check a URL, poke a deployed page, one-off DOM read, a test that needs no intervention from him. | Cheaper in tokens than `bsk` and there's no window to watch. Doesn't touch his profile. Default for throwaway work. |
| **`browsentic`** (MCP → Vimma, his daily browser) | **Default for anything in his logged-in browser**: read, click, type, screenshot in Vimma while he watches the tab. | Greg picked it on 2026-10-25 as faster to work with than `bsk`. The MCP refuses submits, uploads, captchas and tab switches by design: those go to Greg or the side panel. Skill: `agent-skills/browsentic/`. |
| **`bsk`** (BrowserSkill → Comet Agent Window) | The task needs Comet specifically, or a separate Agent Window with `request-help` for login / 2FA / captcha. | Rides his real Comet session in a visible Agent Window, and `bsk request-help` hands the human steps back to him. |

Rule of thumb: **his login or his eyes → `browsentic`; Comet or a human step
mid-flow → `bsk`; otherwise → `agent-browser`.** One of `browsentic` / `bsk`
goes once the trial settles (Greg, 2026-10-25); don't remove either before he
says so.

**Minting a token or API key on a site behind his login is a `bsk` job, not a
step list.** On 2026-09-28 Greg got the Docker Hub PAT instructions twice and
answered "to co mam zrobić? ogarnij przez bsk". The flow that worked: `bsk`
to the token page, `request-help` for the login, a click to generate,
`request-help` for Greg to copy the token, `session stop`. The token then goes
from the clipboard straight into the consumer (`pbpaste | docker login
--password-stdin`, or `op item create`), never echoed, never in a file, and
`pbcopy < /dev/null` clears the clipboard afterwards. Offer to store it in
1Password and say plainly if the consumer keeps it in plaintext
(`~/.docker/config.json` without a credential helper does).

**`claude-in-chrome` is retired (2026-08-23).** It kept hanging, and `bsk` +
`agent-browser` cover everything it did. `mcp__claude-in-chrome__*` is in
`permissions.deny`. If those tools still show up in a session's registry, the
Chrome extension is still paired — turn it off with `/chrome` ("Enabled by
default") or disable the extension in `chrome://extensions`. Do **not** reach
for those tools, and don't propose bringing the stack back.

## Where the Agent Window lands

`bin/bsk` (stage 28 → `~/bin`, ahead of `~/.local/bin/bsk` on PATH) wraps the
real CLI: on `session start` it parks the new Agent Window on aerospace
workspace `test` (8) without taking focus, and passes every other subcommand
straight through. Greg looks at it with `ctrl-8`. Call `~/.local/bin/bsk` by
path only to skip the park step (a8481fff).

## Health check

`bsk doctor` — every row `ok` or `N/A`. `0 browsers connected` means the
extension in Comet is off or gone; re-enable it at
`chromewebstore.google.com/detail/hhcmgoofomhgciiibhipgmgkgnoenaoi`.

`agent skill up to date → N/A no agent skill installed` is **expected**, not a
fault: the skill dir is named `bsk` (so Greg can just say "bsk"), while
`bsk install-skill` looks for `browser-skill`. `agent-skills/bsk/` is the source
of truth; doctor simply can't see it.

**macOS only.** The lab is headless — no browser, no `bsk` there.

**`doctor` all `ok`, yet `navigate` / `tab create` → `Host access is
restricted by policy`** is Comet ≥155 refusing `chrome.debugger.attach`
because the extension has a non-empty `runtime_blocked_hosts` in
`ExtensionSettings`, not MDM and not the extension (5666f824, ~15 calls). Fix:
an empty `runtime_blocked_hosts` for `hhcmgoofomhgciiibhipgmgkgnoenaoi`, then a
full restart: `osascript -e 'quit app "Comet"'`, `pgrep -x Comet` empty, `open
-a Comet` (⌘Q alone left the process running). Greg keeps bsk on Comet; don't
propose Chrome.
