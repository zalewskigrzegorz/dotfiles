---
name: tina-announce
description: Announce something out loud on Greg's house speakers through Tina (the announce-agent on the lab), or fire one of its event recipes. Use when Greg wants the household told something — "ogłoś na głośnikach", "niech Tina powie/ogłosi", "powiedz domownikom", "puść ogłoszenie", "krzyknij że...", "announce that...", "say it on the speakers", "tell the house" — or wants to trigger an announce event by hand ("odpal event pralki", "trigger the weather announcement"). Wraps the `tina` nushell command. NOT for playing an existing audio file on a speaker (that's cast-audio) and NOT for notifications meant only for Greg's Mac.
---

# tina-announce

The `tina` command is a **nushell** def in `~/.config/nushell/autoload/tina.nu`.
The Bash tool runs zsh and `nu -c` does not load autoload dirs, so always source
it explicitly — bare `tina …` gives `command not found`:

```bash
nu -c 'source ~/.config/nushell/autoload/tina.nu; tina -t livingroom "paczki czekają na dole"'
```

Outer single quotes, message in double quotes. Diacritics are fine.

## Verbatim is the default — keep it that way

```bash
tina "paczki czekają na dole"        # literal TTS, no LLM. What you type is what she says.
tina -t livingroom "kolacja gotowa"  # one zone
tina --dry "..."                     # don't play
tina --ai "..."                      # phrase it with the LLM
tina log 5                           # recent events (structured table)
```

**Default to verbatim.** Greg's use case is passing a message to another floor,
so the wording is the point. `--ai` routes through the generator, which rephrases
and has invented whole sentences in the past ("Matka, ale na dole jest naprawdę
gorąco!" from an unrelated message). Only reach for `--ai` when he explicitly
wants it composed rather than read.

Both paths do the same ElevenLabs TTS in Tina's voice — `--ai` only adds the
rewrite. Verbatim goes through `POST /say`, which answers synchronously with
what actually played; `--ai` goes through `POST /trigger/announce`.

## Before you broadcast

Speakers are audible to the whole household, so treat it as an outward-facing
action: **confirm the target with Greg** unless he named it himself. Zones:

| Target | Speakers | Note |
|---|---|---|
| `all` (default) | `greg_office` + `nest` (kitchen) | **does NOT reach the living room** — `fireplace` is only a swap/fallback for a busy or offline Nest |
| `office` | `greg_office` | AirPlay |
| `kitchen` | `nest` → falls back to `fireplace` | |
| `livingroom` | `fireplace` → falls back to `nest` | |
| `auto` | presence-based (phones), night-mode aware | may land on a single speaker only |

Source of truth: `MEDIA_PLAYERS` in
`lab:/opt/homelab/services/announce-agent/src/zones.js`.

Night hours: `auto` applies night-mode volumes; the explicit zones do not, so a
late `-t all` is full volume.

## Firing event recipes

```bash
tina trigger washing_machine_done          # waits, prints what she said
tina trigger meal --params {kind: dinner}
tina trigger weather_outgoing --dry
```

Recipe names come live from `GET /triggers` (TAB-completes for Greg). Each recipe
composes from its own facts — **don't smuggle free text through one** (e.g.
`service_alert --params {msg: ...}`); it ignores your text and announces
something unrelated. Free text has exactly two homes: `tina` and `tina --ai`.

## Verify it landed

Verbatim prints `played_on` immediately. Otherwise:

```bash
tina log 3                        # ts, trigger, spoken line, played_on, event_id
tina log 5 --all                 # include recipe-driven events
tina replay <event_id> -t kitchen
```

`status: ok` with empty `played_on` means nothing came out of a speaker — check
`silenced_reason` (`no_target` = that zone has no live media_player).

## Where it lives

- `POST /say` (literal) and `POST /trigger/:name` on `http://192.168.50.10:3001`
- Route: `lab:/opt/homelab/services/announce-agent/src/server.js`
- LLM path: `recipes/announce.yaml` + `prompts/announce.md`
- **All of it is baked into the container image**, only `data/` is bind-mounted.
  After editing any of those on the lab: `ssh lab 'cd
  /opt/homelab/services/announce-agent && docker compose up -d --build'` — a
  `docker cp` alone is lost on the next rebuild.
