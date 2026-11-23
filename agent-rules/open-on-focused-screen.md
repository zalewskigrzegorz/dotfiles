---
description: GUI windows Claude opens for Greg go through open-here, never plain open
alwaysApply: true
---

# Windows You Open Land Where Greg Is Looking

Plain `open` reused a System Settings window parked on the laptop screen while Greg sat at the external monitor.

- **`open-here <args>` instead of `open`** for anything he must act on: System Settings panes, apps, files, Finder folders (a plain `open` passthrough; HyprMac switches to the app's workspace). Plain `open` is fine for things he needn't see. Say in one line what you opened and what to click.
- **After `open-here` of a window he must click in**: one `screencapture -x` into the scratchpad, `Read` it, then "okno jest na środku, nad terminalem". `agent-desktop launch` doesn't switch the workspace: follow it with `open-here -a <App>`. "Nie widzę okna" → `open-here` again plus a shot, no step list (5f10fa56).
- **A fix ending in "untick X in System Settings" is this case** too (input sources for `ctrl+space`, AirPlay Receiver).
- **The first `open -a` of a non-App-Store app can raise a Gatekeeper dialog on the laptop screen**: say where it is before asking for the click; don't click it for him, `xattr -d com.apple.quarantine` only after his yes.
