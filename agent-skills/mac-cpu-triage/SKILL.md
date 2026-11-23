---
name: mac-cpu-triage
description: Diagnose why a macOS process eats CPU or memory and whether it's tunable or a symptom. Use when Greg points at Activity Monitor or a screenshot of a hot process, or says "te procesy szaleją", "co żre CPU", "czemu to mieli", "proces wisi", "load jest wysoki", "wentylatory szaleją", "why is X using so much CPU", "what's pegging my mac", "high CPU", "fan is spinning", "myszka się zacina", "kursor staje", "trackball przerywa". Covers the triage flow and known culprits (Kandji ESF, AX window managers, Slack renderer, sketchybar, WindowServer stalls).
---

# mac-cpu-triage

A hot process is often a **symptom**: observers (Kandji ESF, Spotlight, HyprMac, WindowServer) burn CPU in proportion to what *other* processes do. Ask what it reacts to before naming it the culprit.

## Flow (stop when the verdict is clear)

1. **Top now:** `ps -Ao pid,ppid,%cpu,%mem,user,comm -r | head -15` and `uptime` (load ≫ cores = spawn/IO storm from git/node/exec churn, not one thread). `ps -r` ranks; don't trust lifetime `%cpu` for "right now".
2. **Attribute:** `sample <PID> 2 -mayDie | sed -n '/Call graph/,/^$/p' | grep -E "[0-9]{3,} +[A-Za-z]" | head -25`. Skip idle waits (`mach_msg`, `RunCurrentEventLoopInMode`); find the deepest heavy frame in the app's code. Root-owned (Kandji ESF) can't be sampled without sudo: attribute by event volume from step 1.
3. **Driver:** exec/file amplifiers (ESF, `mds`) ← git, node, builds, `softwareupdated`, reindex. AX observers (HyprMac) ← one chatty app (animated Electron, stuck "Loading" window, menubar timer): sample the WM, quit suspects one at a time. WindowServer ← redraw volume.
4. **Verdict:** **Tunable** (config, quit chatty app, file upstream) · **Untunable amplifier** (reduce churn, move it to a VM/lab, ask IT for MDM path exclusions) · **Fixable symptom** (watchdog that restarts).

## Known culprits

- **`io.kandji.KandjiAgent.ESF-Extension`** (root) — untunable amplifier, spikes with multi-agent git/node work. Can't kill/throttle. Levers: path exclusions on `~/Code` from the Kandji admin, churn on the lab, fewer parallel agents. `~/Code/personal/bazgroly/dotfiles/analysis/2026-06-26-kandji-esf-aerospace-cpu.md`.
- **AeroSpace** (retired 2026-10-25, history): refresh storms came from one chatty app, not window count or the `on-window-detected` rules; never tune those.
- **`Slack Helper (Renderer)`** pegging 130–185% — handled by `com.greg.slack-watch` → `bin/slack-renderer-watchdog`.
- **sketchybar dies or hangs on display reconfig** — `com.greg.sketchybar-watch` → `bin/sketchybar-watchdog` (dead or no `--query bar` answer in 15 s). "Why did the bar die/restart/lag" → `bin/sketchybar-why` (`-v`), from `com.greg.sketchybar-diag` logs in `~/Library/Logs/sketchybar-diag/`. A bar gone while logs show nothing = render freeze, handled by the display listener.
- **sketchybar event loop** (sketchybar, launchd, notifyd, cfprefsd, WindowServer all hot after a config change): a `forced` handler that runs `sketchybar --update` / `--trigger forced` calls itself. `git log -p --since=2.hours dot_config/sketchybar`, guard the call, `bin/sketchybar-restart` (flags >20% cpu).
- **Cursor freezes 1–10 s** (WindowServer `transaction N timed out` bursts): was JankyBorders with `hidpi=on`, removed for good; don't reinstall. Not the mouse, Options+, CleanShot, refresh rate. `failed set_cursor_surface` alone is noise. Count with `scripts/ws-stall-count.sh [minutes=10]` in the background; the burst right after a refresh change or app restart is that event. Test a Chromium app by killing only its `--type=gpu-process` helper.
- **Cursor jumps, no freezes** (trackpad smooth) → radio: the Bolt receiver next to a USB 3.0 hub. Move it close to the mouse.
- **Input reaches the Mac, UI ignores it:** (1) `scripts/synth-events.sh [minutes]` (flood of `prohibited from synthesizing` = event-tap app); (2) empty `system_profiler SPUSBDataType SPThunderboltDataType` → dock/cable; (3) kill Clop, CleanShot, Raycast, HyprMac in one command with pids re-read by `ps -p` right before `kill` (a stale pid killed JamSQL), bring back one by one; (4) WindowServer → `sudo` split (ops-traps); no input at all → hold Touch ID ~10 s.
- **"Wszystko się zawiesiło, zrestartowałem":** `sysctl -n kern.boottime`, `ls -lt /Library/Logs/DiagnosticReports/`. `forceReset-*.diag` with `btn_rst` = Greg held power, not a panic. `JetsamEvent-*.ips` just before = memory exhaustion: `sed 1d <f> | jq` over `.processes` by `rpages` (×16384 B) grouped by `.name`, plus `.memoryStatus.memoryPages.free`. Growing Gecko GPU process (Vimma) is upstream (Bugzilla 1962210); `about:processes` kills it in place.
- **Audio drops:** `pmset -g assertions` + age of Electron GPU helpers (`ps -o etime`); restart that app, not `coreaudiod`.
- **Spotlight off since 2026-10-23** (`sudo mdutil -ai off`); `mds_*` hot = it was turned back on.

## Don't

- Don't `kill`/`renice` a root MDM extension (locked, respawns).
- Don't call an intermittent problem fixed before ≥10 min or 3× the longest gap held; nothing goes into this skill or Hindsight as "the fix" before that.
- Don't date a problem's start from the tail of a per-minute count; take the first matching log line.
