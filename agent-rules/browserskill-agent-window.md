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

## Two stacks, and only two

| Stack | Use it when | Why |
| --- | --- | --- |
| **`agent-browser`** (skill, Chrome/CDP, own profile) | **A quick shot Greg doesn't need to watch**: fetch a public page, scrape docs, check a URL, poke a deployed page, one-off DOM read, a test that needs no intervention from him. | Cheaper in tokens than `bsk` and there's no window to watch. Doesn't touch his profile. Default for throwaway work. |
| **`bsk`** (BrowserSkill → Comet Agent Window) | **Greg wants to see it happen**, you're researching something *together*, the site is behind a login, or it blocks bots / needs a captcha or 2FA. Also anything long and multi-step. | Rides his real Comet session in a visible Agent Window, and `bsk request-help` hands the human steps back to him. |

Rule of thumb: **needs Greg's eyes, his login, or gets bot-blocked → `bsk`;
otherwise → `agent-browser`.**

**`claude-in-chrome` is retired (2026-08-23).** It kept hanging, and `bsk` +
`agent-browser` cover everything it did. `mcp__claude-in-chrome__*` is in
`permissions.deny`. If those tools still show up in a session's registry, the
Chrome extension is still paired — turn it off with `/chrome` ("Enabled by
default") or disable the extension in `chrome://extensions`. Do **not** reach
for those tools, and don't propose bringing the stack back.

## Health check

`bsk doctor` — every row `ok` or `N/A`. `0 browsers connected` means the
extension in Comet is off or gone; re-enable it at
`chromewebstore.google.com/detail/hhcmgoofomhgciiibhipgmgkgnoenaoi`.

`agent skill up to date → N/A no agent skill installed` is **expected**, not a
fault: the skill dir is named `bsk` (so Greg can just say "bsk"), while
`bsk install-skill` looks for `browser-skill`. `agent-skills/bsk/` is the source
of truth; doctor simply can't see it.

**macOS only.** The lab is headless — no browser, no `bsk` there.
