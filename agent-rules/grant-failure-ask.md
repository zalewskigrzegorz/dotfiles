---
description: When a macOS permission/TCC grant fails, stop and ask Greg — never auto-reset or work around it
alwaysApply: true
---

# Grant / Permission Failure — Ask, Don't Auto-Fix

When a command fails because a **macOS permission or TCC grant is missing**
(e.g. the `reminders` CLI returning `you need to grant reminders access`, or any
"wants to access your Reminders/Calendar/Contacts/Photos/…" Privacy denial),
**STOP and ask Greg interactively** before taking any corrective action.

## Why

A failed grant is not automatically a bug to route around. It may mean Greg was
mid-action, deliberately dismissed the prompt, or simply hasn't allowed it yet.
Silently working around the denial can undo something he was intentionally doing.

## Rules

1. **Never run destructive TCC fixes on your own.** `tccutil reset <service>`
   wipes the grant for **every** app, not just the terminal — that is Greg's
   call, not yours. Do not run it, or any reset/workaround, without an explicit
   go-ahead from him in the moment.
2. **Surface the failure plainly, then ask.** Say which grant is missing and
   offer the options (re-run and click Allow, enable it in System Settings, or
   reset TCC), and let Greg pick.
3. **Don't retry in a loop.** One failure → report + ask. Do not keep re-firing
   the same command hoping the grant appears.
4. This applies to any Privacy-gated service on macOS, not just Reminders.
