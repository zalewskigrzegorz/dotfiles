---
name: hyprmac
description: Greg's tiling window manager HyprMac (replaced AeroSpace 2026-10-25) and his fork of it. Use when a HyprMac shortcut "nie działa" / "Ctrl przestał działać", a window floats, lands on the wrong workspace or monitor, "Arrangement rejected", "Could not hide the current workspace", sketchybar shows stale workspaces, when changing HyprMac keybinds, app pins, names or padding, and when fixing, building, testing or opening PRs from the fork (~/Code/personal/HyprMac). Not for Dygma layout edits (/dygma).
---

# HyprMac

Upstream `zacharytgray/HyprMac` (cask `zacharytgray/hyprmac/hyprmac`). Greg runs **HyprMac Debug**
built from his fork until his PRs land; open ones are listed in
`~/Code/personal/bazgroly/dotfiles/notes/2026-10-25-hyprmac-test.md`.

## Config: merge, never overwrite

- `~/Library/Application Support/HyprMac/config.json` is a **symlink into iCloud Drive**.
  `monitor-config.json` next to it is local (max splits, top padding per monitor, by
  `NSScreen.localizedName`).
- **`bin/hyprmac-config` is the only writer.** It owns `keybinds`, `windowRules`,
  `excludedBundleIDs`, `hyprKey`, `workspaceNames`, `statusExport*` and the top padding,
  keeps every setting Greg made in HyprMac's UI and every UI chord on a combo it doesn't use,
  backs up to `~/.local/state/hyprmac/backups/`, quits the running app (release or Debug),
  writes, relaunches. Copying a whole generated config over the live one wiped Greg's
  settings once ("nie rób tak").
- Every action needs a chord: `mergeNewDefaults` re-injects a default for any action missing
  from the file. That is how Hypr+Return → Terminal came back; `launchApp` is parked on an
  unreachable chord for that reason. Retired chords go in `RETIRED`, or merge keeps them as
  "UI chords".
- Hypr = left Control. Each Hypr chord has a twin on plain `control` (bit 8): HyprMac 0.18
  drops quick Ctrl chords as "stale" (fork PR #47 fixes the cause).
- Chords Greg can't press on the Dygma (Ctrl+Opt+Shift+…) get moved to 2–3 key chords; ask
  before inventing 4-key ones.
- Workspace N lives on screen `(N-1) % screens`, left to right; keys are grouped per monitor
  and keep the AeroSpace names (chat, term, code, notes | web, test, mail | media, misc, mac).

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
  minimum (`min-size app hint … source=appHint`). Restarting HyprMac clears it; fork PR #53
  fixes it.
- **Window ignores a height and sits on the screen bottom** after it once covered the whole
  screen (slider dragged to 0): new windows behave. The frame check allows +20 pt for
  terminals.
- **"Could not hide the current workspace" on Hypr+F** → hide corner on a screen that a lower
  screen shares an edge with, or a window taller than the corner screen (fork PR #55).
- **A browser won't tile in a 948-wide slot**: Vimma's minimum width is ~980. Correct refusal.
- **"Arrangement rejected"** = the tiled drag's sizing failed and was rolled back; the
  `actual=` in that line is after rollback, not the failing frame.

## sketchybar

The fork exports `~/Library/Application Support/HyprMac/state.json` (opt-in
`statusExportEnabled`) and runs `sketchybar-watcher notify --event hyprmac` as its hook; the
watcher reads the file. Clicks call `open -g -b com.zachgray.HyprMac.debug
"hyprmac://focus?workspace=N"` (`-b` because both installed apps claim the scheme). Top
padding per monitor keeps tiles under the 36 pt bar.

## Fork workflow

- Repo `~/Code/personal/HyprMac`, remotes `origin` = fork, `upstream`. One branch per fix
  from `main`; read the repo's `CLAUDE.md` (xcodegen, frozen wire keys, "no repro, no guess fix").
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
