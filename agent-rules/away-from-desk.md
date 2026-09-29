---
description: When Greg says he is away from the Mac, give text to paste and never start GUI automation that needs a click on the desktop
alwaysApply: true
---

# Greg away from the Mac → text first, no GUI automation

"jestem na spacerze", "z telefonu", "nie ma mnie przy kompie", "bsk nie
zadziała" mean nobody can click a dialog on the desktop. On 2026-09-29 an
`osascript` → Messages send hung the full 180 s on a TCC consent prompt and had
to be killed.

- Give the copy-paste text or the link **first**; he sends it from the phone.
- Do not start Messages, Mail, Finder or any GUI-scripting `osascript`, and no
  `bsk` (it opens a window on the Mac).
- If a GUI call is unavoidable, `timeout 15 osascript …` so a consent dialog
  fails fast. On timeout: one line, then the phone route.
- The `grant-failure-ask` rule still applies once he is back: report the
  missing grant, do not reset TCC.
