---
name: tina-announce
description: Announce something out loud on Greg's house speakers through Tina (the announce-agent on the lab), or fire one of its event recipes. Use when Greg wants the household told something — "ogłoś na głośnikach", "niech Tina powie/ogłosi", "powiedz domownikom", "puść ogłoszenie", "krzyknij że...", "announce that...", "say it on the speakers", "tell the house" — or wants to trigger an announce event by hand ("odpal event pralki", "trigger the weather announcement"). Wraps the `tina` nushell command. NOT for playing an existing audio file on a speaker (that's cast-audio) and NOT for notifications meant only for Greg's Mac.
---

# tina-announce

The `tina` command is a **nushell** def in `~/.config/nushell/autoload/tina.nu`.
The Bash tool runs zsh and `nu -c` does not load autoload dirs, so always source
it explicitly — bare `tina …` gives `command not found`:

```bash
nu -c 'source ~/.config/nushell/autoload/tina.nu; tina announce -t livingroom "paczki czekają na dole"'
```

Outer single quotes, message in double quotes. Diacritics are fine.

## `tina announce` speaks, bare `tina` asks

One word = one intention. The two you will confuse if you skim:

| You want | Command |
|---|---|
| the house to hear your exact words | `tina announce "..."` |
| an answer to a question | `tina "..."` |

**Bare `tina "..."` used to be the literal announcement and is now the AI.** If
you type the old form out of habit, Tina answers your shopping list as if it were
a question instead of reading it out. Announcements always carry `announce`.

```bash
tina announce "paczki czekają na dole"   # literal TTS, no LLM. What you type is what she says.
tina announce -t livingroom "kolacja gotowa"  # one zone
tina announce -d "..."                   # don't play
tina announce -r "..."                   # -r/--rephrase: let the LLM word it
tina history 5                           # recent spoken events (structured table)
```

**Default to verbatim.** Greg's use case is passing a message to another floor,
so the wording is the point. `-r/--rephrase` routes through the generator, which
rewrites and has invented whole sentences in the past ("Matka, ale na dole jest
naprawdę gorąco!" from an unrelated message). Only reach for it when he
explicitly wants the message composed rather than read.

Both paths do the same ElevenLabs TTS in Tina's voice — `--rephrase` only adds
the rewrite. Verbatim goes through `POST /say`, which answers synchronously with
what actually played; `--rephrase` goes through `POST /trigger/announce`.

## Before you broadcast

Speakers are audible to the whole household, so treat it as an outward-facing
action: **confirm the target with Greg** unless he named it himself. Zones:

| Target | Speakers | Note |
|---|---|---|
| `all` (default) | `greg_office` + `nest` (kitchen) + `fireplace` (living room) | whole house |
| `office` | `greg_office` | AirPlay |
| `kitchen` | `nest` → falls back to `fireplace` | |
| `livingroom` | `fireplace` → falls back to `nest` | |
| `auto` | presence-based (phones), night-mode aware | may land on a single speaker only |

Source of truth: `MEDIA_PLAYERS` in
`lab:/opt/homelab/services/announce-agent/src/zones.js`.

Night hours: `auto` applies night-mode volumes; the explicit zones do not, so a
late `-t all` is full volume.

## Asking about the house

```bash
tina "jaka jest pogoda"
tina "czy mogę wyjść z domu"
tina -d "co się dzieje w domu"    # answer printed, not spoken
```

This is the jarvis-brain path (`POST /ask`), which picks its own tools. The old
`ask` recipe below still exists on the announce-agent and is reachable as
`tina workflow ask --params {question: "..."}`; the `--legacy` flag that used to
select it is gone.

Recipe `ask` fetches the whole sensor bundle on every call — weather + rain in
the next hour, PM2.5, indoor/outdoor temps, which doors are open, which
appliances are running, hob/AC left on, where the dogs are, litter box, Lucy's
last weight. The prompt makes her answer only the question and add a second
sentence only when a reading changes the decision (rain when asked about a walk,
hob left on when asked about leaving). Adding a device to `fetch:` does not make
her chattier.

History comes from **Homey Insights** via the `insights` fetcher source — Homey
keeps the time-series itself, nothing is stored on our side. Today's dog walks,
outdoor min/max, "did the washer run today" all work.

```yaml
- { id: daisy_hist, source: insights, device: Daisy Tracker,
    capability: in_geofence, merge_gap_minutes: 35, min_minutes: 20 }
```

Booleans come back as `false_periods` / `true_periods` (each with `count`,
`periods`, `last_at`, `last_minutes`, `minutes_total`); numbers as
`min`/`max`/`avg`/`first`/`last`. Which direction is interesting depends on the
device — out of a geofence is `false`, a washer running is `true`.

**Dog walks are approximate, and saying so is part of the answer.** The geofence
covers a road next to the house, so walking past registers a spurious return;
`merge_gap_minutes` stitches those back together and `min_minutes` drops blips.
On top of that the tracker only polls every ~30 min in `power_saving`, so short
walks can be invisible and timestamps land on poll boundaries. The prompt
therefore prefers `dogs_last_out` ("wyszły o 20:02, na 30 minut") over a walk
count, and never says "na pewno".

Not every capability has a log — `logged: false` comes back instead of an error,
so recipe facts must guard on it (`(x && x.logged) ? … : null`).

## Firing event recipes

```bash
tina workflow washing_machine_done          # waits, prints what she said
tina workflow meal --params {kind: dinner}
tina workflow weather_outgoing --dry
```

Recipe names come live from `GET /triggers` (TAB-completes for Greg). Each recipe
composes from its own facts — **don't smuggle free text through one** (e.g.
`service_alert --params {msg: ...}`); it ignores your text and announces
something unrelated. Free text has exactly two homes: `tina announce` and
`tina announce -r`.

## Verify it landed

Verbatim prints `played_on` immediately. Otherwise:

```bash
tina history 3                    # ts, trigger, spoken line, played_on, event_id
tina history 5 --all              # include recipe-driven events
tina replay <event_id> -t kitchen
```

The three read-only views are named after whose record they are — `tina history`
is her mouth (what she said), `tina brain` her head (questions, tools, cost),
`tina house` her house (sensor events).

`status: ok` with empty `played_on` means nothing came out of a speaker — check
`silenced_reason` (`no_target` = that zone has no live media_player).

**`GET /api/events` is a projection — it has no `facts` or `fetched`.** To debug
what a recipe actually computed, fetch the single event:
`curl -s http://lab:3001/api/events/<event_id> | jq .facts`. Reading `facts:
null` off the list view and concluding the fetch failed is a trap.

## Where it lives

- `POST /say` (literal) and `POST /trigger/:name` on `http://192.168.50.10:3001`
- Route: `lab:/opt/homelab/services/announce-agent/src/server.js`
- LLM path: `recipes/announce.yaml` + `prompts/announce.md`
- **All of it is baked into the container image**, only `data/` is bind-mounted.
  After editing any of those on the lab: `ssh lab 'cd
  /opt/homelab/services/announce-agent && docker compose up -d --build'` — a
  `docker cp` alone is lost on the next rebuild.
