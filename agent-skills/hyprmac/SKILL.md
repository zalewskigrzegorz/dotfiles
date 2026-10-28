---
name: hyprmac
description: Greg's tiling window manager HyprMac (replaced AeroSpace 2026-10-25) and his fork of it. Use when a HyprMac shortcut "nie działa" / "Ctrl przestał działać", a window floats, lands on the wrong workspace or monitor, "Arrangement rejected", "Could not hide the current workspace", sketchybar shows stale workspaces, when changing HyprMac keybinds, app pins, names or padding, and when fixing, building, testing or opening PRs from the fork (~/Code/personal/HyprMac), and when picking or recommending a keyboard shortcut for any other app (Vimma, Logi Options+, nvim, Dygma), since plain Ctrl chords are HyprMac's. Not for Dygma layout edits (/dygma).
---

# HyprMac

Upstream `zacharytgray/HyprMac` (cask `zacharytgray/hyprmac/hyprmac`). Since v0.19.0 (f8d3190)
upstream has merged every fork PR, so Greg runs the **release** `HyprMac.app` (login item) again
(2026-10-28). `HyprMac Debug.app`, built from the fork's `greg-nightly`, stays installed for the
next fork fix. **Switching = which one runs**: quit one, `open -a` the other, swap the login item.
Never both at once: they tile the same windows and write the same config. `bin/hyprmac-config` and
the sketchybar clicks follow whichever runs (`pgrep -x "HyprMac Debug"`). History of the fork work:
`~/Code/personal/bazgroly/dotfiles/notes/2026-10-25-hyprmac-test.md`.

## Choosing a shortcut for another app

Plain `ctrl+…` chords (`ctrl+tab`, `ctrl+1…0`, `ctrl+arrows`) belong to HyprMac.
For another app propose `cmd+alt+…` (the Chrome tab keys, chosen in `f5f50f6`).
"Vimma has ctrl+tab by default" got "eee ctrl tab to chyba workspace zmienia w
HyprMac" (7c37679b).

## Config: merge, never overwrite

- `~/Library/Application Support/HyprMac/config.json` is a **symlink into iCloud Drive**.
  `monitor-config.json` next to it is local, keyed by `NSScreen.localizedName` (`DELL U3225QE`,
  `C34H89x`, `Built-in Retina Display`): max splits, `workspaceMonitors`,
  `outerPaddingPerMonitor` (`{"top": 37}`, sides optional), `statusExportEnabled`,
  `statusHookCommand`. HyprMac watches only config.json, so it is quit before this file is written.
- **`bin/hyprmac-config` is the only writer.** It owns `keybinds`, `windowRules`,
  `excludedBundleIDs`, `hyprKey`, `workspaceNames`, and in monitor-config `workspaceMonitors`,
  `outerPaddingPerMonitor` and `statusExport*`,
  keeps every setting Greg made in HyprMac's UI and every UI chord on a combo it doesn't use,
  backs up to `~/.local/state/hyprmac/backups/`, quits the running app (release or Debug),
  writes, relaunches. Check the relaunch after ~5 s with `pgrep -x HyprMac` (release) or
  `pgrep -x "HyprMac Debug"`: each matches only its own build (673e7d5e). Copying a whole generated config over the live one wiped Greg's
  settings once ("nie rób tak").
- Every action needs a chord: `mergeNewDefaults` re-injects a default for any action missing
  from the file. That is how Hypr+Return → Terminal came back; `launchApp` is parked on an
  unreachable chord for that reason. Retired chords go in `RETIRED`, or merge keeps them as
  "UI chords".
- Hypr = left Control. Each Hypr chord has a twin on plain `control` (bit 8): HyprMac 0.18
  dropped quick Ctrl chords as "stale" (fixed upstream by PR #47; the twins stay harmless).
- Chords Greg can't press on the Dygma (Ctrl+Opt+Shift+…) get moved to 2–3 key chords; ask
  before inventing 4-key ones.
- Key N = workspace N, exactly the AeroSpace layout, pinned by `workspaceMonitors`:
  Dell 1–5 chat, term, code, misc, notes (left hand; deep blacks, sharp text) | ultrawide 6–9
  web, media, test, mail (right hand; media, meetings, manual testing) | laptop 0 mac (helper,
  screen sharing). A disconnected monitor's workspaces fall back to the formula home
  `(N-1) % screens`, so the laptop alone holds all ten. The same order lives in `spaces.lua`,
  the watcher's `workspaceOrder` and `bin/dygma-cheats`; change all four together.

## Diagnose from logs, not guesses

- **Debug build file log:** `~/Library/Logs/HyprMac/com.zachgray.HyprMac.debug.log`, verbose
  (`matched: <action>`, `frame write trace`, `min-size record`, `park rejected`). Filter by
  time: `awk '$1 >= "2026-10-25T23:00:00"' <log> | rg '…'`.
- **Unified log** for the release app: `/usr/bin/log show --last 30m --info --predicate
  'subsystem BEGINSWITH "com.zachgray.HyprMac"'` (`--debug` for more; rolls off fast).
- **Full state on demand:** `kill -USR1 $(pgrep -x "HyprMac Debug")` writes a state dump
  (`screen=…`, `wsN home=… assigned=[…] hidden=[…]`) to the log.
- **Window geometry:** a 10-line Swift script with `CGWindowListCopyWindowInfo` + `NSScreen`
  frames (CG top-left coordinates) beats reading screenshots; compare with the target in the log.

## Known traps (each cost a long hunt)

- **All shortcuts dead, `hypr ↓/↑` still logged** → an app holds Secure Keyboard Entry and
  macOS sends event taps no keyDowns. `ioreg -l -w 0 | rg -o '"kCGSSessionSecureInputPID"=[0-9]+'`,
  then `ps -p <pid>`. Terminal.app was it (opened by the default Hypr+Return). Not the fix,
  not the config.
- **Windows float / drags fail `preflight(noRoom)`** → one failed resize became an app-wide
  minimum (`min-size app hint … source=appHint`). Restarting HyprMac clears it; fixed upstream
  by PR #53.
- **Window ignores a height and sits on the screen bottom** after it once covered the whole
  screen (slider dragged to 0): new windows behave. The frame check allows +20 pt for
  terminals.
- **"Could not hide the current workspace" on Hypr+F** → hide corner on a screen that a lower
  screen shares an edge with, or a window taller than the corner screen (fixed upstream, PR #55).
- **A browser won't tile in a 948-wide slot**: Vimma's minimum width is ~980. Correct refusal.
- **"Arrangement rejected"** = the tiled drag's sizing failed and was rolled back; the
  `actual=` in that line is after rollback, not the failing frame.

## sketchybar

HyprMac exports `~/Library/Application Support/HyprMac/state.json` (opt-in
`statusExportEnabled` in monitor-config.json) and runs `sketchybar-watcher notify --event hyprmac` as its hook; the
watcher reads the file. Clicks call `open -g -b <bundle> "hyprmac://focus?workspace=N"`, where the
bundle is `com.zachgray.HyprMac.debug` while Debug runs, else `com.zachgray.HyprMac` (`-b` because
both installed apps claim the scheme). Top
padding per monitor keeps tiles under the 36 pt bar.

## Build branch: `greg-nightly`

`greg-nightly` is `upstream/main` plus every still-open PR branch from `origin`
(73759dde). Run `scripts/rebuild-live.sh` before every build: it rebuilds the
branch from scratch, force-pushes with `--force-with-lease` and returns to the
branch you were on; merged or closed PRs drop out by themselves. With no open PRs
it exits with "no open PRs found": then nightly is just `upstream/main`, build that.
The script is local-only (`.git/info/exclude`), so say so. Never rebuild `local/live`
by hand.

## Focus bugs

- Log: `~/Library/Logs/HyprMac/com.zachgray.HyprMac.debug.log`; patterns
  `switch:` and `focus\(\d+\) activate (ok|dropped)`, filtered to the test's
  time window with `awk`.
- Frontmost app over time: a watcher script that exits by itself after N
  seconds, run in the background.
- macOS 27 drops `activate()` when the app is still inactive 100 ms later (log
  line `activate dropped — app still inactive 100ms after activate()`); the fix
  fronts the app through SkyLight (issue #56, PR #57). Not verified on 26.

## Fork workflow

- Repo `~/Code/personal/HyprMac`, remotes `origin` = fork, `upstream`. One branch per fix
  from `main`; read the repo's `CLAUDE.md` (xcodegen, frozen wire keys, "no repro, no guess fix").
  That file is upstream's: its hub host and `/usr/local/bin` paths are the author's. On
  Greg's Macs resolve tools with `command -v xcodegen gh` (`/opt/homebrew/bin`), and don't
  edit the file, it would ride into every PR (73759dde).
- Gate: `find build/sizing/isolated-tests/home -name config.json -delete; ./scripts/test-isolated.sh --debug-variant`
  (~5 min, check `Executed N` > 0, 0 failures), then `ponytail:ponytail-review`.
- Live build = throwaway branch `local/live` (the stacked base plus every open fix branch
  merged), built signed so Accessibility survives rebuilds:
  `xcodebuild -project HyprMac.xcodeproj -scheme "HyprMac Debug" -configuration Debug
  -derivedDataPath build/live CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=AM4DX85G8P
  "CODE_SIGN_IDENTITY=Apple Development: zalewski.grzegorz@icloud.com (M66MB9XHFN)"
  PROVISIONING_PROFILE_SPECIFIER= build`. An ad-hoc (`-`) build needs the Accessibility entry
  removed with − and re-added on every rebuild. The keychain needs Apple's WWDR G3
  intermediate or the identity shows "0 valid".
- Install: quit "HyprMac Debug", replace `/Applications/HyprMac Debug.app`, `open` it, check
  `AXIsProcessTrusted=true` in the file log. If it quit right after Greg granted access,
  launch it again.
- PRs: issue first (`Fixes #N`), body through `greg-voice`, live result and what is not
  covered stated plainly. Screenshots go on an orphan `pr-assets` branch of the fork and are
  linked by raw URL (gh can't upload images). The maintainer welcomes AI-assisted PRs and
  asked for all of them.
- Live tests with Greg go step by step (see the ADHD rule): one action per popup, note the
  time, read the log, then the next step.
