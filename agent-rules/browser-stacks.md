---
description: Which browser stack to use — browsentic (Greg's logged-in Vimma), the vimma MCP (fallback), agent-browser (unattended) — and the rules for acting inside his logged-in sessions.
alwaysApply: true
---

# Browser stacks

`bsk` (BrowserSkill → Comet) was removed on 2026-10-30, after Browsentic was
configured. Don't propose bringing it back. Comet itself stays installed.

| Stack | Use it when | Why |
| --- | --- | --- |
| **`browsentic`** (MCP → Vimma, his daily browser) | **Default for anything in his logged-in browser**: read, click, type, screenshot in Vimma while he watches the tab. | Rides his real session, action cues show him each element before it is touched. The MCP refuses submits, uploads, captchas and tab switches by design: those go to Greg or the side panel. Skill: `agent-skills/browsentic/`. |
| **`vimma`** (MCP → Vimma's agent workspace) | **Fallback** when Browsentic is down (`browsentic_status` not connected and `browsentic start` does not fix it). | Separate tabs with their own cookies, so no logins of his; the first call asks Greg in Vimma. Showing a page, sending a form or paying asks every time. |
| **`agent-browser`** (skill, Chrome/CDP, own profile) | **A quick shot Greg doesn't need to watch**: fetch a public page, scrape docs, check a URL, poke a deployed page, a test that needs no intervention from him. | Cheapest in tokens, no window, doesn't touch his profile. Default for throwaway work. |

Rule of thumb: **his login or his eyes → `browsentic`; it is down →
`vimma`; otherwise → `agent-browser`.** A site that blocks `agent-browser`
(otomoto.pl and other anti-bot classifieds) goes to `browsentic`.

## Rules inside his logged-in sessions

1. **Read-only by default.** Navigating and reading is fine; sending,
   posting, paying, deleting or changing account settings needs his go-ahead
   in the moment, even in YOLO mode. Browsentic blocks submits for MCP
   callers, but a plain click on a "Save" or "Delete" button in a single-page
   app is not a submit and goes through, so this rule is the gate there.
2. **Never export credential material.** No cookies, `localStorage` auth
   blobs, passwords or bearer tokens to a file, a log, the transcript or an
   outward-facing message. Browsentic hands back sealed placeholders
   (`⟦password:…⟧`); pass them through unchanged, never rebuild them.
3. **Human steps are his.** Login, 2FA, a captcha nothing can answer, an
   irreversible confirm: stop, say what is ready, let him do it, then carry
   on in the same tab.
4. **Blocked sites stay blocked.** `SITE_BLOCKED` (ING, 1Password) is his
   list in the Browsentic settings: no retry, no other route.
5. **Close what you opened** with `page_closeTab` when the task ends.

**Minting a token or API key on a site behind his login is a browser job, not
a step list.** On 2026-09-28 Greg got the Docker Hub PAT instructions twice and
answered "to co mam zrobić? ogarnij to". Flow: `browsentic` to the token page,
Greg logs in, a click to generate, Greg copies the token. The token then goes
from the clipboard straight into the consumer (`pbpaste | docker login
--password-stdin`, or `op item create`), never echoed, never in a file, and
`pbcopy < /dev/null` clears the clipboard afterwards. Offer to store it in
1Password and say plainly if the consumer keeps it in plaintext
(`~/.docker/config.json` without a credential helper does).

**A step list for Greg that starts with "open <url>" in his browser: open it
yourself** with `browsentic` in the same turn, before the list ("moze sam
otworz?", 127b663a). Login, DevTools and copying a token stay his steps, and
the token still never reaches the transcript, a file or your clipboard.

**`claude-in-chrome` is retired (2026-08-23).** It kept hanging.
`mcp__claude-in-chrome__*` is in `permissions.deny`. If those tools still show
up in a session's registry, the Chrome extension is still paired — turn it off
with `/chrome` ("Enabled by default") or disable the extension in
`chrome://extensions`. Do **not** reach for those tools, and don't propose
bringing the stack back.

**macOS only.** The lab is headless — no browser there.
