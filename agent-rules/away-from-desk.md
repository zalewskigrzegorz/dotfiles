---
description: When Greg says he is away from the Mac, give text to paste and never start GUI automation that needs a click on the desktop
alwaysApply: true
---

# Greg away from the Mac → text first, no GUI automation

"jestem na spacerze", "z telefonu", "nie ma mnie przy kompie" mean nobody can click a dialog on the desktop. On 2026-09-29 an
`osascript` → Messages send hung the full 180 s on a TCC consent prompt and had
to be killed.

- Give the copy-paste text or the link **first**; he sends it from the phone.
- Do not start Messages, Mail, Finder or any GUI-scripting `osascript`, and no
  browser step that needs his login, 2FA or a click on the Mac.
- If a GUI call is unavoidable, `timeout 15 osascript …` so a consent dialog
  fails fast. On timeout: one line, then the phone route.
- The `grant-failure-ask` rule still applies once he is back: report the
  missing grant, do not reset TCC.
- **Before a step that needs `sudo`, Touch ID or a click on the Mac** (`op`
  through the desktop app, a 1Password push, a TCC prompt), ask first with
  `AskUserQuestion` whether he is at the Mac: "Jestem, odpalaj" (Recommended)
  / "Nie ma mnie, odłóż". A blind `op document edit` timed out after 60 s on
  an unanswered Touch ID (2026-10-23). "Odłóż" → park the step, say what
  waits, carry on with the rest.
- **Mac frozen or deaf to input** ("nie reaguje", "wiesza się", writing from
  the phone): no `AskUserQuestion`, it renders on the machine he cannot touch.
  One plain-text question with a one-word answer, numbered steps for physical
  actions, nothing typed into his pane (2b9b89b1).
