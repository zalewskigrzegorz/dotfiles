---
description: When Greg says he is away from the Mac, give text to paste and never start GUI automation that needs a click on the desktop
alwaysApply: true
---

# Greg away from the Mac → text first, no GUI automation

"jestem na spacerze", "z telefonu", "nie ma mnie przy kompie" mean nobody can click a dialog on the desktop (an `osascript` → Messages send hung 180 s on a TCC prompt).

- Give the copy-paste text or the link **first**; he sends it from the phone.
- No Messages, Mail, Finder or GUI-scripting `osascript`, no browser step that needs his login, 2FA or a click on the Mac.
- An unavoidable GUI call runs as `timeout 15 osascript …`; on timeout, one line, then the phone route. Once he is back, `grant-failure-ask` applies: report the missing grant, don't reset TCC.
- **Before a step that needs `sudo`, Touch ID or a click on the Mac** (`op` through the desktop app, a 1Password push, a TCC prompt) ask with `AskUserQuestion`: "Jestem, odpalaj" (Recommended) / "Nie ma mnie, odłóż". "Odłóż" → park the step, say what waits, carry on with the rest.
- **Mac frozen or deaf to input** ("nie reaguje", "wiesza się", writing from the phone): no `AskUserQuestion` (it renders on the machine he cannot touch). One plain-text question with a one-word answer, numbered steps for physical actions, nothing typed into his pane (2b9b89b1).
