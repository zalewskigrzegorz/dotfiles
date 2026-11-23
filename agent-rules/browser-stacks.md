---
description: Which browser stack to use — browsentic (Greg's logged-in Vimma), the vimma MCP (fallback), agent-browser (unattended) — and the rules for acting inside his logged-in sessions.
alwaysApply: true
---

# Browser stacks

| Stack | Use it when |
| --- | --- |
| **`browsentic`** (MCP → Vimma, his daily browser) | **Default for his logged-in browser**: read, click, type, screenshot while he watches. Rides his session; the MCP refuses submits, uploads, captchas and tab switches by design (those go to Greg). Skill: `agent-skills/browsentic/`. |
| **`vimma`** (MCP → Vimma's agent workspace) | **Fallback** when Browsentic is down (`browsentic_status` not connected and `browsentic start` doesn't fix it, or `DAEMON_UNREACHABLE`). Go straight to `vimma_screenshot` / `vimma_read_page`, never `screencapture`; say "Browsentic nieaktywny, jadę na Vimmie". Own tabs and cookies; showing a page, sending a form or paying asks every time. |
| **`agent-browser`** (skill, Chrome/CDP, own profile) | **Unattended throwaway work**: public page, docs scrape, URL check, a deployed page, a test needing no intervention. Cheapest in tokens. |

Rule of thumb: **his login or his eyes → `browsentic`; down → `vimma`; otherwise → `agent-browser`.** Sites that block `agent-browser` (otomoto.pl, anti-bot classifieds) → `browsentic`. `bsk` was removed 2026-10-30 (Comet stays installed); `claude-in-chrome` is retired and in `permissions.deny`: if its tools show up, turn the extension off (`/chrome` or `chrome://extensions`), never propose either back. macOS only, the lab has no browser.

## Rules inside his logged-in sessions

1. **Read-only by default.** Sending, posting, paying, deleting or changing account settings needs his go-ahead in the moment, even in YOLO. A plain click on "Save"/"Delete" in a single-page app is not a submit and goes through, so this rule is the gate. "Cofnij"/"wycofaj" is not a go-ahead for Delete: undo only what the tool did itself or ask; delete only after a named "usuń to" (02fd3d1c).
2. **Never export credential material** (cookies, `localStorage` auth, passwords, bearer tokens) to a file, log, transcript or message. Pass Browsentic's sealed placeholders (`⟦password:…⟧`) through unchanged, never rebuild them.
3. **Human steps are his**: login, 2FA, an unanswerable captcha, an irreversible confirm. Stop, say what is ready, carry on in the same tab after.
4. **`SITE_BLOCKED`** (ING, 1Password) is his list: no retry, no other route.
5. **Close what you opened** with `page_closeTab` when the task ends, not while his hand test on that tab is pending.
6. **After one `TARGET_NOT_FOUND` read the state**: `page_closeTab`'s error lists open tabs (a missing id is closed); for an element, `page_getPageInfo`, then a stable selector, never the same `text`+`role` again or a generated `#dialog-<uuid>`.
7. **`WebFetch` 429 or no price on a shop page** → same turn `page_openTab` + `page_extractText`, no retry popup.

**Minting a token or API key behind his login is a browser job, not a step list** ("to co mam zrobić? ogarnij to"). `browsentic` to the token page, Greg logs in, a click to generate, Greg copies it. The token goes from the clipboard straight into the consumer (`pbpaste | docker login --password-stdin`, `op item create`), never echoed or written to a file; offer to store it in 1Password, then `pbcopy < /dev/null` as the last step (233482bc). Say if the consumer keeps it in plaintext (`~/.docker/config.json` without a credential helper).

**A step list that starts with "open <url>" in his browser: open it yourself** with `browsentic` in the same turn (127b663a). Login, DevTools and copying a token stay his.
