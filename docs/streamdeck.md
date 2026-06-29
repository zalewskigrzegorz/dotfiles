# Stream Deck + — layout reference

Functional reference for the Stream Deck + setup: what lives on each page, what
each key/dial does, and how to edit + reproduce it. Read this before touching the
layout so you know what moves.

> **Status:** design landed 2026-06-17 (spec/plan in `bazgroly/dotfiles/`).
> **2026-06-19 PIVOT — read this first.**

## ⚠️ 2026-06-19 — Homey Pro plugin is the way; MCP editing is abandoned

What we learned the hard way:

- **`streamdeck-mcp` (disk editing) does NOT work reliably.** It writes `ProfilesV3`
  files on disk, but the Elgato app keeps its own in-memory/cloud state and
  **overwrites disk edits on restart/sync**. Net effect: MCP-written pages (e.g. the
  old "office" page) silently vanish from the app — they exist on disk but the GUI
  shows a different set of pages. **Do not edit the layout via MCP.** MCP is fine for
  *reading* the current profile, nothing else.
- **Configure the deck in the Elgato GUI, by hand.** That is the only reliable path.
- **Home control = the `Homey Pro` Stream Deck plugin (Adapted AS).** Native, GUI-
  configured, supports **dials** (rotate temp/dim, push = toggle) and **live tiles**.
  Actions: **Toggle Device** (on/off), **Set Device State** (mode/scene), and dial
  controls. This replaces the old `bin/office-*` scripts *on the deck*. (The free
  `Homey Pro` covers it; `Homey Pro Plus` is the paid tier — Greg's Plus purchase
  broke 2026-06-19, awaiting Elgato support, so build on the free plugin.)
- **AC now has native `onoff` in Homey** (Office/Bedroom/Living/Fun-room AC) — the
  home-lab agent fixed the Tuya→HA→Homey exposure. So Toggle Device works for AC on/off.
- The `bin/office-*` + `homey-cap` scripts and the HA `switch.klima_*` still stand —
  they power **Raycast / CLI / cross-machine** control, just not the deck.

### AC on a dial, with on/off (Homey Pro dial)

On a dial running the Homey Pro **dial** action for `Office AC`:

1. Add the Homey Pro dial action to a dial slot, pick device **Office AC**.
2. **Rotate** → adjusts `target_temperature` (already working).
3. Set **Push (dial press)** → **Toggle Device** on `Office AC` → turns the AC on/off.

So rotate = temperature, press = power. Same recipe for any room AC.

> ⚠️ **Known limitation (2026-06-23):** the Adapted Homey Pro Plus plugin binds ALL dial
> events (rotate / press / touch) to the **same capability** — so a temperature dial's
> **press just re-applies the value, it does NOT toggle on/off**. Press≠rotate-action is
> not possible, and dials aren't documented on the Adapted site at all. **Workaround:**
> keep temp on the dial, put on/off on an adjacent **key** (Toggle Device). Feature
> request sent to the dev (odd@adapted.no) asking for an independent dial-press action.

## 2026-06-23 — FINAL layout design (brainstormed on draw.lab)

This supersedes the room-*folder* "SmartHome layout" further down. Built interactively;
implement in the Elgato GUI with the Homey Pro plugin once Greg's plugin access is back.

### Navigation model (two dials)

- **Right dial (encoder 4) = CONTEXTS** — cycles top-level pages:
  `Office · Dev/GitHub · Meeting · Slack · Music · HomeLab · Gaming`.
- **Encoder 3 = ROOM select** — within the home/Office view, cycles rooms
  (`Office → Living → Bedroom → …`); the keys show the **selected room's** devices.
  (Effectively a page per room; the dial pages through them.)
- **Principle:** if something is on a dial, it gets **no separate key**.
- **Temp = ONE seasonal dial per room:** summer → AC, winter → thermostat
  (swap mechanism TBD at implementation "so as not to break things"). Rooms with AC
  have **no thermostat key** (temp lives on the dial). Rooms without AC put the
  thermostat on that dial. AC dial: rotate = temp, push = on/off.

### Office (landing / default room)

Keys (4×2): `Aura` · `Left` · `Right` (lights) · `🔌 Listwy →` (folder) · `Scena` ·
`All-off` · `CO2/air` (live) · *(room-dial selects room)*
- **🔌 Listwy** = FOLDER (Create Folder) — desk + greg are multi-gang strips with many
  switches (one has an **air purifier**), so they get their own sub-page, not a key.
- Dials: `Aura dim` (push=toggle) · `Office AC temp` (push=on/off, seasonal) ·
  `◉ ROOM select` · `◉ PAGES (contexts)`.

### Rooms (encoder-3 cycles; keys = selected room)

Temp dial = seasonal (AC if present, else thermostat). `◉3=ROOM`, `◉4=PAGES` constant.

| Room | Keys | Dial 1 / 2 |
|---|---|---|
| Living | Lamp · Living Lt · Dinner · Fireplace · Twinkly · Win-L · Win-R · All-off | Lamp dim / Living AC (seasonal); Fireplace speaker vol optional |
| Bedroom | Bedroom Lt · Switch · Greg Night · Esti Night · All-off | Night dim / Bedroom AC (seasonal) |
| Bathroom | Light · LED · Mirror · Button · Star Proj · All-off | Star Proj dim / Thermostat |
| Fun room | Neon · Left · Right · All-off | Neon dim / Fun AC (seasonal) |
| Kitchen | Kitchen Light | Thermostat / Nest volume |
| Hall 🔒 | **Door LOCK** (⚠ guarded push) · Hall Light · Hall Ledstrip | Ledstrip dim / — |
| Garden | Garage Lt · Garden L · Garden R · Watering · All-off | Garden dim / — |
| Other | Toilet Lt · Toilet Mirror · Shower LED · Lucy · Stairs · Wardrobe · Upstairs · Garage Sw | — / Toilet+Lucy thermostats |

### Dev / GitHub (merged context)

Lazygit dropped (Greg works in the IDE). Keys = live tiles from the **GitHub plugin**
(installed): `PR-y do mojego review (live count)` · `Moje PR-y + CI status` ·
`GH notifications` · `gh-dash / PRs in browser`. 4 keys free (optional Claude / screenshot).
Dials: `Zoom / font` · — · — · `◉ PAGES`.

### Meeting (Insta360 Present + MuteDeck)

The **Insta360 "Present" app shortcuts are GLOBAL hotkeys** (work in Zoom/Meet/Teams),
so camera/framing is reliable on the deck via Stream Deck **Hotkey** actions — NOT
app-focused (this corrects the earlier Insta360 caveat). Keys:
`Mic mute ⌥⌘X` · `Camera ⌥⌘O` · `Share start ⌥⌘S` · `Share end ⌥⌘E` ·
`Cinematic zoom ⌥B` · `Remote ⌥⌘R` · `Framing/layout` · `Leave call`.
Dials: `Mic gain` · `Speaker` · `Cam zoom` · `◉ PAGES`. MuteDeck = cross-app mute/cam backup.

### HomeLab (context)

HTTP triggers to the lab via the **API Request** plugin (GUI-configured, survives — NOT
MCP). Keys: `n8n workflow trigger (webhook)` · `Lab status (live tile, poll)` ·
`Tina / announce event (lab:3001)` · `draw.lab / tools (open)`. 4 keys + 3 dials free.
Dial 4 = `◉ PAGES`.

### Still to draw / define (later)

- **Slack** · **Music/Spotify** — already on the deck, keep as-is.
- **Gaming** — own session (Gaming Pixel Light + gaming mode); Greg undecided on contents.
- **🔌 Listwy folder** — desk + greg multi-gang strips; needs per-switch labels from Greg
  (which switch is the air purifier, etc.) before drawing.

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
(live via API Request `gh`) · Claude · console-ninja · screenshot; dials
zoom · scroll · workspace · volume. Add only on confirmation.

## SmartHome layout (rozpiska) — ⚠️ SUPERSEDED by the 2026-06-23 final design above

> Kept for reference. The room-**folder** model below was replaced by the **room-dial**
> model (encoder-3 cycles rooms, keys reflect the selected room) — see the 2026-06-23
> section. The device inventory table at the end is still valid.

Goal: a SmartHome section where you pick a **room**, then control that room's
significant devices. Build entirely in the Elgato GUI.

**Mechanics (Homey Pro plugin):**
- Key on/off → **Toggle Device** (pick the Homey device). Works for lights, sockets, AC (native `onoff`), lock.
- Mode / scene → **Set Device State**.
- Dial → Homey Pro **dial** action: rotate = `target_temperature` (AC) or `dim` (light); **push = Toggle Device** (see AC-dial recipe at top).
- Room navigation → Stream Deck **Create Folder** action (opens a sub-page; a ⬅ back key is added automatically).

### SmartHome landing page — 8 room folders (4×2)

```
[Office]    [Living]    [Bedroom]   [Bathroom]
[Fun room]  [Kitchen]   [Hall 🔒]   [Garden]
```
Landing dials: `Office AC temp` · `Living AC temp` · *(free)* · `page switch`.
Minor rooms (Toilet, Lucy, Stairs, Wardrobe, Upstairs, Garage) → optional 9th "Other" folder.

### Room folders — keys + dials

**Office** — Aura · Gaming · Desk socket · Greg socket · Left · Right · **AC on/off** · ⬅
Dials: `Aura dim (push=toggle)` · `AC temp (push=on/off)` · — · ⬅

**Living Room** — Lamp · Living Light · Dinner Light · Fireplace · Twinkly · **AC on/off** · Window L · ⬅
Dials: `Lamp dim` · `AC temp` · `Fireplace speaker vol` · ⬅

**Bedroom** — Bedroom Light · Switch · Greg Night · Esti Night · **AC on/off** · Thermostat · — · ⬅
Dials: `Night light dim` · `AC temp` · `Thermostat temp` · ⬅

**Bathroom** — Light · LED · Mirror · Button · Star Projector · **Thermostat on/off** · — · ⬅
Dials: `Star Projector dim` · `Thermostat temp` · — · ⬅

**Fun room** — Neon · Left · Right · **AC on/off** · Thermostat · — · — · ⬅
Dials: `Neon dim` · `AC temp` · — · ⬅

**Kitchen** — Kitchen Light · **Thermostat on/off** · Nest · — · — · — · — · ⬅
Dials: `Thermostat temp` · `Nest volume` · — · ⬅

**Hall 🔒** — **Door (LOCK)** · Hall Light · Hall Ledstrip · — · — · — · — · ⬅
Dials: `Ledstrip dim` · — · — · ⬅  — lock = Toggle Device `locked`; guard against accidental press.

**Garden** — Garage Light · Garden L · Garden R · Watering · — · — · — · ⬅
Dials: `Garden dim` · — · — · ⬅

### Full controllable-device inventory (per Homey zone, 2026-06-19)

Source for the map above; pull fresh with `homey-cap` / the Homey API if devices change.

| Zone | Devices (controllable) |
|---|---|
| Office | Aura Light, Gaming Pixel Light, Left/Right Light, desk socket, greg socket, **AC**, Thermostat |
| Living Room | Lamp, Living Light, Dinner table Light, Fireplace, Twinkly_Curtain, **AC**, Window switch L/R, Fireplace Speaker |
| Bedroom | Bedroom Light, Switch, Greg/Esti Night Light, **AC**, Thermostat |
| Bathroom | Light, LED, Mirror Light, Button, Star Light Projector, Thermostat |
| Fun room | Neon light, Left/Right Light, **AC**, Thermostat |
| Kitchen | Kitchen Light, Thermostat, Nest (speaker) |
| Hall | **Door (lock)**, Hall Light, Hall Ledstrip |
| Garden | Garage Light, Garden L/R Light, Watering |
| Toilet | Toilet/Mirror/Shower Light, Thermostat |
| Other | Lucy room Light+Thermostat, Stairs Light, Wardrobe Light, Upstairs Light, Garage Switch, House Number Sign, Recuperator (Top) |

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

## Editing the layout — GUI only (streamdeck-mcp DEPRECATED)

**Edit in the Elgato GUI by hand.** See the 2026-06-19 pivot at the top: the
`streamdeck-mcp` writes get overwritten by the app's own state, so MCP-written
pages disappear. The MCP (`uvx streamdeck-mcp`, project-scoped in `.mcp.json`) is
kept **only for reading** the current profile (`streamdeck_read_profiles` /
`streamdeck_read_page`) — never for writing the layout.

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
