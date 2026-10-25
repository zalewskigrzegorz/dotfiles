---
description: GUI windows Claude opens for Greg go through open-here, never plain open
alwaysApply: true
---

# Windows You Open Land Where Greg Is Looking

Plain `open "x-apple.systempreferences:…"` reused a System Settings window
parked on the `mac` workspace (laptop screen) while Greg sat at an external
monitor, and he never noticed it (2026-10-20).

- **Use `open-here <args>` instead of `open`** for anything that shows a window
  Greg must act on: System Settings panes, apps, files, Finder folders. It
  is a plain `open` passthrough now, since HyprMac switches to an app's
  workspace when the app is activated.
- Plain `open` stays fine for things he does not need to see (a URL handed to a
  background app, a scripted step with no window).
- Still say in one line what you opened and what he should click there.
- **A fix that ends in "untick X in System Settings" is this case**, even when
  the task never mentions windows: input sources for `ctrl+space`, AirPlay
  Receiver on `:7000` (b2750378, c333538c both used plain `open`).
- **The first `open -a` of an app from outside the App Store can raise a
  Gatekeeper dialog on the laptop screen**, not where Greg looks (a1108d95).
  Say in one line where it is before asking for the click. Don't click it for
  him; `xattr -d com.apple.quarantine` only after his yes.
