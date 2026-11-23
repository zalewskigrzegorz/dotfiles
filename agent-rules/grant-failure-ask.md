---
description: When a macOS permission/TCC grant fails, stop and ask Greg — never auto-reset or work around it
alwaysApply: true
---

# Grant / Permission Failure: Ask, Don't Auto-Fix

A missing macOS permission or TCC grant (`reminders` returning `you need to grant reminders access`, any Reminders/Calendar/Contacts/Photos/… Privacy denial) may mean Greg was mid-action or dismissed the prompt on purpose. **Stop and ask him** before any corrective action.

1. **Never run a TCC fix on your own**: `tccutil reset <service>` wipes the grant for **every** app; no reset or workaround without his explicit go-ahead in the moment.
2. **Name the missing grant, then ask** with the options: re-run and click Allow, enable it in System Settings, or reset TCC.
3. **One failure → report + ask**, no retry loop.
4. Holds for every Privacy-gated service.
5. **Switch on and macOS keeps asking → check the app, not TCC.** A modified bundle breaks an ad-hoc signature and macOS drops the grant (Ghostty's `macos-icon` writes an `Icon` file into the bundle, fixed in `0c035f5`). First `codesign --verify --deep --strict <app>` and the bundle's mtime, then which process `tccd` names as responsible (an agent's `screencapture` counts as Ghostty, not tuios), then anything that modifies the bundle. The PiP patch ad-hoc re-signs Ghostty after each update (`agent-desktop status` `denied` with `auth_value=2`, `-67050` in `tccd`): Greg removes Ghostty with `−` in Accessibility and Screen Recording, adds it with `+`, Touch ID; you check `status` and one `snapshot`. The patch stays (5f10fa56).
