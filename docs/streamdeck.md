# Stream Deck + — layout reference

Functional reference for the Stream Deck + setup: what lives on each page, what
each key/dial does, and how to edit + reproduce it. Read this before touching the
layout so you know what moves.

> **Status:** design landed 2026-06-17 (spec/plan in `bazgroly/dotfiles/`). Implementation
> is staged across phases — sections below flagged **TBD** are not yet wired.

## Hardware

- **Stream Deck +** (model `20GBD9901`) — **8 keys** (4×2 grid) + **4 dials** + a **touch strip**.
- The old 15-key MK.2 / XL (`20GAT9901`, "Default Profile") is retired — delete it.

## Guiding principle: ONE profile, pages switched by a dial

A single profile **`1.Main`** holds every context as a **page**. You page between
them by **turning a dial** (the dots along the bottom of the touch strip are the
page indicator). Keys are reused per page, which solves "8 keys is too few"
without locking you into a fixed context.

**Auto-switch by active app was rejected.** Reason: when Greg is in the browser
with a meeting open, an app-based auto-switch would force the "browser" context
and hide the "meeting" controls — e.g. he could no longer turn off the AC. Too
rigid. Paging by dial is manual and always reachable, so it stays.

So: context = **page** (not a separate profile), navigation = **dial**, manual.

`Emoji Keyboard` (10 pages) stays as its own separate profile, invoked manually.

## Pages on `1.Main`

Paged with a dial. Each page can have its own dial assignments (the + supports
different dials per page).

| Page | Keys | Dials |
|---|---|---|
| Meeting / camera | cam off · mic mute · zoom · record + screenshot · pan/tilt/zoom (hotkeys) | Mic · Speaker · Camera zoom · AC temp |
| Slack | channels (team, right-city, poland, am-living) + DM avatars | Mic · Speaker · Brightness · Spotify |
| Spotify | clipboard · like · explicit · shuffle · info · loop-song · context · loop-context | playback · volume · my-playlists · new-releases |
| Office | see key map below | Volume · Brightness · **AC temp** · Spotify |

### Meeting / camera page

- **mic mute / cam off** = MuteDeck — **global**, work regardless of focused app.
- **pan / tilt / zoom** (touch strip: `right/left/center`, `up/down`, `zoom AI`) are
  **hotkeys** — they only act on the **currently focused app**. Camera framing/zoom
  goes through the **Insta360 Link Controller** (best-effort; no rich public API),
  so these work only while Link is the active app. See the camera caveat below.
- Dials: `Mic` · `Speaker` · `Camera zoom` · `AC temp`.

### Slack page

Channel shortcuts + DM avatars. Dials: `Mic` · `Speaker` · `Brightness` · `Spotify`.
Slack-status shortcuts (Focus / dog-walk / clear) from the old `Experiments`
profile may be folded in here (plugin `net.ellreka.slack-status`) — **TBD**, only
if Greg actually uses them.

### Spotify page

Spotify Essentials controls 1:1 (clipboard, like, explicit, shuffle, info,
loop-song, context, loop-context). Dials: `playback` · `volume` · `my-playlists` ·
`new-releases`.

### Office page (NEW — Homey control)

Replaces the old empty/unfinished page. Dashboard + direct office control.

Key map (4×2):

```
[Aura light]    [Gaming light]   [Desk socket]    [AC mode cool/heat/off]
[CO2/air live]  [Rekup. boost]   [Light scene]    [empty / future]
```

Dials: `Volume` · `Brightness` · **`AC temp`** (rotate = Office AC ±0.5 °C, push = on/off) · `Spotify`.

Keys are wired to the `bin/` scripts (each invoked via Stream Deck "Open"):

| Key | Action | Script | Device |
|---|---|---|---|
| Aura light | toggle on/off | `office-light aura` | Office Aura Light |
| Gaming light | toggle on/off | `office-light gaming` | Gaming Pixel Light |
| Desk socket | toggle on/off | `office-light desk` | Office desk socket |
| AC mode | cycle off→cool→heat | `office-ac-mode` | Office AC |
| CO2/air live | live CO2 readout (API Request, see below) | `office-co2` | Airq |
| Rekup. boost | ventilation on + fan up | `office-rekup-boost` | Recuperator |
| Light scene | set a light scene | `homey-cap set <aura-id> lightScenes.light <n>` | Office Aura Light |
| AC temp (dial) | rotate ±0.5 °C / push toggle | `office-ac-temp +`/`-` | Office AC |

`CO2/air live` colors by threshold: green `<800`, yellow `<1200`, red `≥1200`
(Mocha Neon hex from `docs/mocha-neon-palette.md`). All actions go through the
**direct Homey API** (no n8n in between).

Base helper for all of these: `homey-cap get|set <deviceId> <capability> [value]`
(`bin/`, reads token from `~/.config/streamdeck/homey-token`, host from
`$HOMEY_HOST` or `homey.local`).

### Dev page — optional, NOT built

Out of MVP. Candidate if Greg wants it back: lazygit · tests · PR-review count
(live via API Request `gh`) · Claude · console-ninja · sesh · screenshot; dials
zoom · scroll · workspace · volume. Add only on confirmation.

## Camera caveat (important)

- **Global** (work from any app): mic mute + cam off via **MuteDeck**.
- **App-focused only** (act on the focused window): pan / tilt / zoom hotkeys via
  the **Insta360 Link Controller**. If the Link app isn't the active app the
  framing/zoom keys do nothing — that's expected, not a bug. Insta360 has no rich
  public API, so framing is best-effort through the Link Controller.

## Required plugins (manual reinstall)

These do **not** flow through chezmoi — install from the Elgato Marketplace by
hand after a wipe:

- **MuteDeck** — global mic/cam mute (Meeting page).
- **Spotify Essentials** — Spotify page controls.
- **Slack** — Slack channel/DM page.
- **slack-status** (`net.ellreka.slack-status`) — Focus / dog-walk status (if folded into Slack page).
- **API Request** (BarRaider / marketplace; alt: `mjbnz/streamdeck-api-request`) —
  live readouts (CO2, and any future PR/health counts) via polling + per-response icon color.

## Editing the layout via streamdeck-mcp

Edits go through the community MCP `verygoodplugins/streamdeck-mcp`, registered
**project-scoped** in `~/Code/dotfiles/.mcp.json` only (not global, not in REDACTED_ORG).
It writes `ProfilesV3` files on disk directly (full dial/`Encoder` + touch-strip
support) and preserves `button.raw` (so Spotify/MuteDeck plugin settings survive).

- Run: `uvx streamdeck-mcp`.
- **The Stream Deck app MUST be closed when the MCP writes**, otherwise it throws
  `StreamDeckAppRunningError`. Workflow for every MCP write:
  `quit Stream Deck app → MCP write → reopen app → verify render`.

**Fallback:** if the MCP can't read/write `ProfilesV3`, edit the layout by hand in
the GUI and export `.streamDeckProfile` to the backup dir. The Homey scripts and
API Request work the same either way (independent of edit method).

## Reproducing the profile (chezmoi)

Source of truth: the exported `+` profile tracked as JSON under
`dot_config/streamdeck/` (diffable, not a binary blob) — `chezmoi apply` restores it.

- `dot_config/streamdeck/1.Main.sdProfile/` — raw `ProfilesV3` profile dir
  (`manifest.json` + `Profiles/*/manifest.json`).
- `dot_config/streamdeck/backups/*.streamDeckProfile` — exported profile snapshots
  as an extra restore path.

> **TBD — source-of-truth format:** raw `ProfilesV3/<uuid>.sdProfile/` JSON (preferred,
> for diffs) vs the exported `.streamDeckProfile`. Decided after the MCP read-test;
> the raw JSON dir is the working assumption.

To restore on a fresh machine: `chezmoi apply` lays down `dot_config/streamdeck/`,
then reinstall the plugins above by hand, then (if needed) re-export to confirm.

## Homey device IDs (zone Office)

| Device | ID | Capabilities |
|---|---|---|
| Office AC | `f4ebfb86-0303-4f51-84a5-e4fb5a3cb3ee` | `target_temperature` (16–88, step 0.5), `climate_mode` (off/cool/heat/dry/fan_only/heat_cool) |
| Airq | `6be72f95-f01b-41fb-acbd-8db97c2d557e` | `measure_co2` / readings (co2, voc, humidity, health) |
| Office Aura Light | `1f76f87b-de89-401a-9ce9-e062ba4d61d2` | `onoff`, `dim`, `lightScenes.light` (0–42) |
| Gaming Pixel Light | `a67a1154-890b-431d-91dc-c880d34b9f7f` | `onoff`, `dim`, `lightScenes.light` (0–242) |
| Recuperator | `d38d966c-799c-450d-a7ae-19736f96041e` | `onoff.modifier2` (Ventilation), `dim` (fan speed) |
| Office desk socket | `291a80cd-07b8-4c1e-a03e-2c637876107d` | `onoff`, `onoff.switch_1..3` |

> **TBD — Homey endpoint:** exact local API URL shape and host (`homey.local` vs IP
> vs `https://<cloudId>.connect.athom.com` fallback) confirmed during implementation.
> Working assumption: `http://$HOMEY_HOST/api/manager/devices/device/<id>` (GET for read,
> `PUT .../capability/<cap>` with `{"value": ...}` for write).

## Token mechanism

The Homey Personal Access Token (Bearer) is **never** plaintext in the repo.

- Staged in `private/streamdeck-homey-token` (gitignored).
- `run_after_05-restore-private-files.sh.tmpl` restores it to
  `~/.config/streamdeck/homey-token` at mode `0600`.
- Scripts read it from `~/.config/streamdeck/homey-token` (override via
  `$HOMEY_TOKEN_FILE`).
- Run `bin/gitleaks-dotfiles` before pushing to confirm the token never leaked into a commit.
