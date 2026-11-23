---
name: hyprmac
description: Greg's tiling WM HyprMac (replaced AeroSpace 2026-10-25) and his fork (~/Code/personal/HyprMac). Use when a HyprMac shortcut "nie działa" / "Ctrl przestał działać", a window floats or lands on the wrong workspace/monitor, "Arrangement rejected", "Could not hide the current workspace", sketchybar shows stale workspaces; when changing keybinds, app pins, names or padding; when fixing, building, testing or opening PRs from the fork; and when picking a shortcut for any other app (Vimma, Logi Options+, nvim, Dygma), since plain Ctrl chords are HyprMac's. Not for Dygma layout edits (/dygma).
---

# HyprMac

Upstream `zacharytgray/HyprMac` (cask `zacharytgray/hyprmac/hyprmac`) merges every fork PR since
v0.19.0, so Greg runs the **release** `HyprMac.app` (login item). `HyprMac Debug.app` is
uninstalled (2026-11-05): two instances tile the same windows. For a fork fix: build, test, quit it,
`lsregister -u` the build; never leave a Debug build registered or as a login item.
`bin/hyprmac-config` follows whichever runs. Fork history: `~/Code/personal/bazgroly/dotfiles/notes/2026-10-25-hyprmac-test.md`.

## Shortcut for another app

Plain `ctrl+…` (`ctrl+tab`, `ctrl+1…0`, `ctrl+arrows`) is HyprMac's. Propose `cmd+alt+…` (7c37679b).

## Config: merge, never overwrite

- `~/Library/Application Support/HyprMac/config.json` is a symlink into iCloud. `monitor-config.json` next to it is local, keyed by `NSScreen.localizedName`: max splits, `workspaceMonitors`, `outerPaddingPerMonitor` (`{"top": 37}`), `statusExportEnabled`, `statusHookCommand`. HyprMac watches only config.json, so quit it before writing this file.
- **`bin/hyprmac-config` is the only writer.** Owns `keybinds`, `windowRules`, `excludedBundleIDs`, `hyprKey`, `workspaceNames` and (monitor-config) `workspaceMonitors`, `outerPaddingPerMonitor`, `statusExport*`; keeps Greg's UI settings and UI chords on unused combos; backs up to `~/.local/state/hyprmac/backups/`; quits, writes, relaunches. Check after ~5 s with `pgrep -x HyprMac` (or `pgrep -x "HyprMac Debug"`; each matches only its build). Copying a generated config over live wiped his settings once.
- Every action needs a chord: `mergeNewDefaults` re-injects missing defaults (that's how Hypr+Return → Terminal came back; `launchApp` is parked on an unreachable chord). Retired chords go in `RETIRED`.
- Hypr = left Control; each Hypr chord has a plain-`control` twin (bit 8), harmless since upstream PR #47.
- Chords he can't press on the Dygma (Ctrl+Opt+Shift+…) → 2–3 key chords; ask before 4-key ones.
- Key N = workspace N, pinned by `workspaceMonitors`: Dell 1–5 chat, term, code, misc, notes | ultrawide 6–9 web, media, test, mail | laptop 0 mac. A disconnected monitor's workspaces fall back to `(N-1) % screens`. Same order in `spaces.lua`, the watcher's `workspaceOrder`, `bin/dygma-cheats`: change all four together.
- **Pins only catch new windows.** After a pin/numbering change Greg presses `Ctrl+;` (Retile All) once.

## Diagnose from logs

- Debug file log `~/Library/Logs/HyprMac/com.zachgray.HyprMac.debug.log` (`matched:`, `frame write trace`, `min-size record`, `park rejected`; focus: `switch:`, `focus\(\d+\) activate (ok|dropped)`), filter by time with `awk '$1 >= "<ISO>"'`.
- Release: `/usr/bin/log show --last 30m --info --predicate 'subsystem BEGINSWITH "com.zachgray.HyprMac"'`.
- State dump: `kill -USR1 <pid>` writes `wsN home=… assigned=[…] hidden=[…]` to the log.
- CLI: `open -g -b <bundle> "hyprmac://workspace?n=N"` (or `focus?workspace=N`), then read `state.json`. Chords can't be sent (`osascript` keystrokes fail 1002): Retile All is Greg's keypress.
- Geometry: a short Swift script with `CGWindowListCopyWindowInfo` + `NSScreen` beats screenshots. Frontmost-app over time: a watcher that exits after N s, in the background.

## Known traps

- **Lag, jumping windows, AX 275–335 ms** → `pgrep -lx HyprMac; pgrep -lx "HyprMac Debug"`: two hits = two instances (Sparkle relaunches the release). Step 0 of every Debug test.
- **Windows vanish after a wallpaper click** → `defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false`, only with his yes.
- **All shortcuts dead, `hypr ↓/↑` still logged** → Secure Keyboard Entry: `ioreg -l -w 0 | rg -o '"kCGSSessionSecureInputPID"=[0-9]+'`, `ps -p <pid>` (was Terminal.app).
- **Floats / `preflight(noRoom)`** → one failed resize became an app-wide minimum (`source=appHint`); restart clears it (PR #53).
- Window ignores height after once covering the screen: new windows behave; +20 pt allowed for terminals.
- **"Could not hide the current workspace" on Hypr+F** → hide corner on a shared edge or a too-tall window (PR #55).
- Vimma won't tile in a 948-wide slot: its minimum is ~980, correct refusal.
- **"Arrangement rejected"** = sizing failed and rolled back; `actual=` is post-rollback.
- macOS 27 drops `activate()` if the app is inactive 100 ms later; fixed via SkyLight (#56/#57), unverified on 26.

## sketchybar

HyprMac exports `state.json` (opt-in `statusExportEnabled`) and runs `sketchybar-watcher notify --event hyprmac`. Clicks: `open -g -b <bundle> "hyprmac://focus?workspace=N"` (`com.zachgray.HyprMac.debug` while Debug runs, else `com.zachgray.HyprMac`). Top padding keeps tiles under the 36 pt bar.

## `greg-nightly`

`upstream/main` + every open PR branch + `origin/perf/*` + `origin/nightly/*`. Run `scripts/rebuild-live.sh` (local-only, `.git/info/exclude`; say so) before every build: rebuilds from scratch, `--force-with-lease`, returns to your branch; "no open PRs …" → build `upstream/main`. Never rebuild `local/live` by hand.

- `nightly/*` = Greg's tools, never a PR. `perf/*` = experiments without a PR. A fix gets an upstream PR only after a measured gain (`scripts/perf-report.sh` before and after). No guess fixes.
- Maintainer may squash PRs by hand and leave them open: before rebasing, compare the PR's files with `upstream/main`; already in → popup, then close with a comment and the sha.
- `nightly/*` rebase conflicting only in `project.pbxproj`: loop `xcodegen generate`, `git add HyprMac.xcodeproj/project.pbxproj`, `GIT_EDITOR=true git rebase --continue` (≤20); any other file stops it.
- Several agents: the main checkout session is the orchestrator (collects branches, runs `rebuild-live.sh` on clean `main`, builds). Workers push and ask it for a rebuild via `env -u TUIOS_PANE_ID tuios send-agent-message`, never build nightly. "Where is tool X" → `tuios list-agents`, `git branch -r`.
- Release: `gh release create --target` takes a branch or full sha (short → 422). `lipo -archs` both apps (universal). Notes via `greg-voice`: signed by Greg, testing only, universal zip, grant Accessibility to **both** `HyprMac` and `HyprMac Usage.app` (dca362b1), link the perf issue.

## Fork workflow

- Remotes `origin` = fork, `upstream`. One branch per fix from `main`; read the repo's `CLAUDE.md` (xcodegen, frozen wire keys, "no repro, no guess fix") but resolve tools with `command -v xcodegen gh` (its paths are the author's) and never edit it.
- Gate: `find build/sizing/isolated-tests/home -name config.json -delete; ./scripts/test-isolated.sh --debug-variant` (~5 min, `Executed N` > 0, 0 failures), then `ponytail:ponytail-review`. One run with a log in the scratchpad, not three.
- Settle/readback changes break tests that model the assumption: `rg -l 'settle|positionFirst|destinationReady' HyprMacTests`, read `TilingEngine*Tests` too (2ee37734).
- `TilingEngine.swift`, `FrameReadbackPoller.swift`, `docs/tiling-algorithm.md` via Serena or ranged `Read`; a full read once per session at most (36ce73f9).
- Live build = throwaway `local/live`, signed so Accessibility survives: `xcodebuild -project HyprMac.xcodeproj -scheme "HyprMac Debug" -configuration Debug -derivedDataPath build/live CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=AM4DX85G8P "CODE_SIGN_IDENTITY=Apple Development: zalewski.grzegorz@icloud.com (M66MB9XHFN)" PROVISIONING_PROFILE_SPECIFIER= build`. Ad-hoc builds need the Accessibility entry re-added each time; the keychain needs Apple WWDR G3.
- Install: quit Debug, replace `/Applications/HyprMac Debug.app`, `open`, check `AXIsProcessTrusted=true`; relaunch if it quit after the grant.
- PRs: issue first (`Fixes #N`), body via `greg-voice`, live result and gaps stated. Screenshots on an orphan `pr-assets` branch, linked by raw URL. The maintainer welcomes AI-assisted PRs.
- Live tests with Greg: the step-by-step rule in `adhd-actions-not-walls.md`.
