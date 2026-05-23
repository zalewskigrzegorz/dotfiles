# Sketchybar internals — Mocha Neon stack

## Processes

| Process | Owner | Purpose |
|---|---|---|
| `sketchybar` | `brew services` LaunchAgent | the bar daemon itself |
| `sketchybar-watcher` (Go) | started by aerospace `after-startup-command` AND by `bin/sketchybar-restart` | pushes `--set` for: aerospace workspace highlighting (`item.1..10`), apple item state (kindavim mode), notif_preview content |
| `cpu_load`, `network_load` | sketchybar event provider helpers | spawned automatically by sketchybar widgets |

`brew services start sketchybar` is the ONLY thing that launches the daemon. Do NOT add `exec-and-forget sketchybar` to aerospace startup — it causes a lock-file race (Bug 2).

## Watcher startup contract

1. Sketchybar daemon starts via brew services.
2. Daemon executes `~/.config/sketchybar/init.lua` → registers items → fires `sketchybar_ready` event after `sbar.end_config()`.
3. Watcher polls `sketchybar --query bar` until it responds (max 10s), then begins pushing `--set` updates.

If the watcher pushes before items register, sketchybar logs `[!] Set: Item not found 'apple'` etc. and the affected widgets stay blank. Mitigation: the watcher's `sketchybar_ready` handler resets the retry counter and calls `scheduleRefresh(st)` so workspace items + apple re-render after every reload.

## Restart procedure

Always use `bin/sketchybar-restart`. It:
1. Kills the watcher first (so its retry loop doesn't fight the restart).
2. Stops sketchybar via brew services + pkill.
3. Restarts via brew services.
4. Waits for `--query bar` to respond (max 10s).
5. Relaunches the watcher.

Manual restart steps are listed in the script itself.

## Update frequencies

| Widget | update_freq | Rationale |
|---|---|---|
| media | 10s | NowPlaying polling (was 2s — too aggressive, raised in Bug 3 fix) |
| battery | 180s | battery state changes slowly |
| calendar | 30s | minute-resolution clock |
| cpu | provided by `cpu_load` event helper | n/a |
| claude_sessions | event-driven (no update_freq) | invalidated by fswatch + 30s idle ticker (followups spec) |
| spaces, apple, notif_preview | pushed by `sketchybar-watcher` | no internal timer |

## Common breakage

- **Bar visible but widgets blank** → watcher race; run `bin/sketchybar-restart`.
- **kindavim mode never updates** → watcher dead; check `pgrep -lf sketchybar-watcher`.
- **notif_preview never appears** → check `bin/sketchybar-watcher/notif_preview.go` polling NotificationCenter sqlite — macOS may have permission-denied the DB (Full Disk Access required).
- **Two sketchybar processes** → aerospace is launching one in addition to brew services. Verify `after-startup-command` does NOT contain a sketchybar line.
- **`[!] Set: Item not found 'apple' / 'item.N'` in `logs/sketchybar.log`** → race during startup or after a reload. Mitigated by `sketchybar_ready` handler in watcher (fixed in `984cec5`) but if it returns, check `readinessMaxMs` in `bin/sketchybar-watcher/main.go`.
