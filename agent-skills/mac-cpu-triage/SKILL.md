---
name: mac-cpu-triage
description: Diagnose why a macOS process is eating CPU (or memory) and decide whether it's tunable or a symptom of something else. Use when Greg points at Activity Monitor, sends a screenshot of a hot process, or says "te procesy szaleją", "co żre CPU", "czemu to mieli", "proces wisi", "load jest wysoki", "wentylatory szaleją", "why is X using so much CPU", "what's pegging my mac", "high CPU", "fan is spinning". Covers the full triage flow (top consumers → per-process sample → driver attribution → verdict) and the classes of culprit on Greg's machine: Kandji ESF (MDM, untunable amplifier of git/node churn), AeroSpace (Accessibility-API refresh storms from chatty apps), Slack renderer hangs, and display-reconfig crashes of sketchybar/aerospace.
---

# mac-cpu-triage

Diagnose a hot macOS process, attribute the CPU to a *driver*, and give a verdict: tunable, untunable-amplifier, or fixable-symptom. Greg does this often — don't reinvent the flow each time.

## Core principle

A process pegging CPU is often a **symptom**, not the cause. Security/observer processes (Kandji ESF, Spotlight, AeroSpace, WindowServer) burn CPU **proportional to what *other* processes do**. Always ask "what is this process *reacting to*?" before declaring it the culprit.

## The flow

Run these in order. Stop as soon as the verdict is clear.

### 1. Top consumers (instantaneous, not lifetime avg)

```bash
ps -Ao pid,ppid,%cpu,%mem,user,comm -r | head -15
uptime   # load average — >cores means a spawn/IO storm, not one heavy thread
```

`%cpu` from `ps -r` is a decaying average, good enough to rank. Load average ≫ core count = many short-lived processes or IO storm (look at git/node/exec churn), **not** a single hot thread.

### 2. Per-process attribution — where does the CPU actually go?

For a process you own (or any non-root), `sample` gives the hot call stack without sudo:

```bash
sample <PID> 2 -mayDie 2>/dev/null | sed -n '/Call graph/,/^$/p' \
  | grep -E "[0-9]{3,} +[A-Za-z]" | head -25
```

Read the heaviest leaf frames. The sample count next to a frame = how many of the N samples sat there. Idle event-loop waits (`mach_msg`, `RunCurrentEventLoopInMode`) are NOT the work — skip them, find the deepest frame with a big count in the app's own code.

Root-owned processes (system extensions like Kandji ESF) **cannot be sampled without sudo** and you usually can't/shouldn't. Attribute them indirectly: their CPU = f(system event volume), so look at what's generating events in step 1.

### 3. Driver attribution

- **exec/file-event amplifiers** (Kandji ESF, any EndpointSecurity client, Spotlight `mds`/`spotlightknowledged`): driven by `exec()` + filesystem event volume. Drivers = git, node, build tools, `softwareupdated`, Spotlight reindex. Confirm by checking step-1 list for those.
- **Accessibility observers** (AeroSpace, other AX window managers): driven by AX notifications from open apps. A single chatty app (Electron showing animated content, an app with a stuck/"Loading" window, a live menubar timer) triggers a full refresh loop. Confirm: `aerospace list-windows --all`, then quit suspects one at a time and re-check CPU.
- **Compositors** (WindowServer): driven by redraw volume — animation, borders (JankyBorders), constant repaints from a busy renderer.

### 4. Verdict

Classify into one of three:

| Verdict | Meaning | Action |
|---|---|---|
| **Tunable** | App you own, real config/usage lever | change config, quit chatty app, file upstream |
| **Untunable amplifier** | MDM/system, CPU = other procs' churn | reduce the churn, or move it off-host (VM/lab); for MDM, request path-exclusions from IT |
| **Fixable symptom** | A specific app hangs/leaks | watchdog that detects + restarts (see below) |

## Known culprits on Greg's machine

- **`io.kandji.KandjiAgent.ESF-Extension`** (root, PID ~523) — Kandji EDR Endpoint Security extension. **Untunable amplifier.** Hooks every exec + file event system-wide. Spikes during heavy git/node multiagent-worktree work, `softwareupdated`, Spotlight reindex. Greg cannot kill/throttle it (MDM). Levers: ask Kandji admin (Roman) for path-exclusions on `~/Code`; run multiagent churn in a VM/lab; cap agent concurrency. See `~/Code/personal/bazgroly/dotfiles/analysis/2026-06-26-kandji-esf-aerospace-cpu.md`.
- **`AeroSpace`** (PID varies) — AX-based tiling WM. Hot path = `scheduleRefreshSession → refresh() → refreshAllAndGetAliveWindowIds`. **Tunable via the chatty app, not window count.** Greg's ~5 windows are fine; a single app spamming AX (Comet on animated pages, a stuck Boom "Loading" window) drives the refresh storm. Find it by quitting suspects. The ~80 `on-window-detected` rules in `aerospace.toml` are NOT the cause (watcher/borders/sketchybar are cheap).
- **`Slack Helper (Renderer)`** — periodically hangs and pegs 130-185%. **Fixable symptom.** Handled by `com.greg.slack-watch` launchd agent → `bin/slack-renderer-watchdog` (restarts Slack after sustained high CPU, with cooldown).
- **sketchybar / AeroSpace dying on display reconfig** (resolution change, monitor connect/disconnect) — known crash class. Both die OR hang (frozen but alive). Watchdogs handle it: `com.greg.aerospace-watchdog` (restarts AeroSpace if dead, 30s) and `com.greg.sketchybar-watch` → `bin/sketchybar-watchdog` (restarts sketchybar if dead OR unresponsive to a `--query bar` liveness probe, 15s). Detection is consequence-based, so it catches any trigger, not just display changes.

## Don't

- Don't declare the top process the culprit before checking what it reacts to.
- Don't trust `ps` lifetime `%cpu` for a "right now" question — use `ps -r` ranking or `sample`.
- Don't try to `kill`/`renice` a root-owned MDM extension — it's locked and respawns.
- Don't propose tuning `aerospace.toml` callback rules for AeroSpace CPU — the cost is AX refresh, not the callbacks.
