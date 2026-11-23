---
name: tina-announce
description: Announce something out loud on the house speakers through Tina (announce-agent on the lab), ask her about the house, or fire one of her event recipes. Use on "ogłoś na głośnikach", "niech Tina powie/ogłosi", "powiedz domownikom", "puść ogłoszenie", "krzyknij że...", "announce that...", "say it on the speakers", "tell the house", "odpal event pralki", "trigger the weather announcement". Wraps the `tina` nushell command. Not for playing an existing audio file (cast-audio) or Mac-only notifications.
---

# tina-announce

`tina` is a nushell def; `nu -c` doesn't load autoload, so source it (bare `tina` = `command not found`):

```bash
nu -c 'source ~/.config/nushell/autoload/tina.nu; tina announce -t livingroom "paczki czekają na dole"'
```

## `tina announce` speaks, bare `tina` asks

Bare `tina "..."` used to announce and is now the AI: a shopping list gets *answered*. Announcements always carry `announce`.

```bash
tina announce "…"              # verbatim TTS via POST /say, prints played_on
tina announce -t kitchen "…"   # one zone;  -d = don't play
tina announce -r "…"           # LLM rewords (POST /trigger/announce)
tina "jaka jest pogoda"        # question (jarvis-brain, POST /ask); -d prints instead of speaking
```

**Default verbatim**: the wording is the point, and `-r` has invented whole sentences. Use `-r` only when Greg wants it composed. Free text has exactly these two homes: never smuggle it through a recipe's `--params` (it's ignored).

## Before you broadcast

The whole house hears it: **confirm the target** unless Greg named it. Zones (source: `MEDIA_PLAYERS` in `mrglaszki:/opt/homelab/services/announce-agent/src/zones.js`):

| Target | Speakers |
|---|---|
| `all` (default) | `greg_office` + `nest` (kitchen) + `fireplace` (living room) |
| `office` | `greg_office` (AirPlay) |
| `kitchen` / `livingroom` | `nest` / `fireplace`, each falls back to the other |
| `auto` | presence-based, night-mode volumes, may hit one speaker |

Explicit zones ignore night mode: a late `-t all` is full volume.

## Recipes and the ask path

- `tina workflow <recipe> [--params {…}] [--dry]` (names from `GET /triggers`); old ask recipe: `tina workflow ask --params {question: "…"}` (`--legacy` is gone).
- Recipe `ask` fetches the whole sensor bundle each call; the prompt answers only the question plus one sentence when a reading changes the decision.
- History comes from Homey Insights (`source: insights`, e.g. `{ id: daisy_hist, source: insights, device: Daisy Tracker, capability: in_geofence, merge_gap_minutes: 35, min_minutes: 20 }`). Booleans → `false_periods`/`true_periods` (`count`, `periods`, `last_at`, `last_minutes`, `minutes_total`); numbers → `min/max/avg/first/last`. Capabilities without a log return `logged: false`: guard facts with `(x && x.logged) ? … : null`.
- **Dog walks are approximate and she says so**: the geofence covers a road (spurious returns, stitched by `merge_gap_minutes`), the tracker polls ~30 min in `power_saving`. Prefer `dogs_last_out` over a count, never "na pewno".

## Verify

- `tina history 3` (`--all` includes recipes), `tina replay <event_id> -t kitchen`. Views: `tina history` (what she said), `tina brain` (questions, tools, cost), `tina house` (sensor events).
- `status: ok` with empty `played_on` = nothing played: read `silenced_reason` (`no_target` = no live media_player).
- `GET /api/events` is a projection without `facts`: debug one event with `curl -s http://mrglaszki:3001/api/events/<event_id> | jq .facts`.
- Answer cards on `announce.mrglaszki.com/day` and `/review` (48 h) show "odpowiedź na: <question>" (`POST /say` takes `question`, `run_id`); older → `tina history N`.

## Where it lives

- `http://192.168.50.10:3001`: `POST /say`, `POST /trigger/:name`; route `services/announce-agent/src/server.js`, LLM path `recipes/announce.yaml` + `prompts/announce.md`.
- Baked into the image (only `data/` is mounted): after editing on the lab, `ssh mrglaszki 'cd /opt/homelab/services/announce-agent && docker compose up -d --build'`; `docker cp` is lost on rebuild.
- **Latency** (076b9dad): the network is noise; time goes to sequential Gemini calls. Measure via `services/jarvis-brain` logs, its `/runs?limit=N` on `:3002`, and `took_ms` in the `/say` log; count model calls before blaming the network. On/off commands go through `src/fast-command.js` first; spoken sentences come from a disk cache.
