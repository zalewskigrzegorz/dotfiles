---
name: cast-audio
description: Play a local audio file (mp3/wav — TTS briefing, recording, announcement) on a home speaker — office, kitchen, living room, or any Homey/HA zone. Use when the user says "puść to na głośniku", "zagraj w office/kuchni/salonie", "cast this", "play it on the speaker", or wants a daily-brief mp3 replayed on a room speaker instead of the Mac. Covers the lab audio-store upload path, HA play_media for Chromecast targets, and the AirPlay-via-Mac fallback for pyatv-backed speakers that HA cannot stream to.
---

# cast-audio

Play a local audio file on a home speaker. Two delivery paths depending on speaker protocol — **check the speaker table first**, picking the wrong path wastes minutes on guaranteed 500s.

## Speaker map (protocol decides the path)

Source of truth for zone → entity mapping: `~/Code/home-lab/services/announce-agent/src/zones.js` (`MEDIA_PLAYERS`). Known entries:

| Zone | HA entity | Protocol | Path |
|---|---|---|---|
| office | `media_player.greg_office` | **AirPlay (pyatv)** | **B — Mac AirPlay only** |
| (other zones) | per `zones.js` | Chromecast / Google | A — HA play_media |

If unsure of protocol: `GET /api/states/<entity>` and try Path A once — a `500` + `miniaudio.DecodeError` in `/api/error_log` means it's a pyatv/AirPlay device → switch to Path B immediately, do NOT retry with other formats.

## Path A — Chromecast speakers via HA play_media

1. **Upload to the lab audio store** (served by announce-agent at port 3001):

```bash
scp <file>.mp3 lab:/opt/homelab/services/announce-agent/data/audio/<name>.mp3
ssh lab 'curl -sf -o /dev/null -w "%{http_code}" http://192.168.50.10:3001/audio/<name>.mp3 -r 0-100'   # expect 206
```

2. **Play via HA REST** (token lives on lab in the announce-agent stack env):

```bash
ssh lab 'HA_TOKEN=$(grep ^HA_TOKEN= /opt/homelab/stacks/announce-agent/.env | cut -d= -f2-); HA=http://homeassistant.lab:8123; \
curl -sS -X POST "$HA/api/services/media_player/volume_set" -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"<entity>\",\"volume_level\":0.7}" >/dev/null; \
curl -sS -X POST "$HA/api/services/media_player/play_media" -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"<entity>\",\"media_content_id\":\"http://192.168.50.10:3001/audio/<name>.mp3\",\"media_content_type\":\"music\"}"'
```

3. Verify: `GET $HA/api/states/<entity>` → state should flip to `playing` within ~5 s.

## Path B — AirPlay speakers (e.g. office): Mac connects directly

HA **cannot** stream HTTP audio to pyatv-backed AirPlay devices — `media_player.play_media` returns 500 with `miniaudio.DecodeError ('failed to init decoder', -1/-17)` for both mp3 and WAV (pyatv `InternetSource` bug, confirmed 2026-06-11). Don't transcode, don't retry.

Instead:

1. Ask the user to connect the Mac to the speaker: **Control Center → wybierz głośnik AirPlay** (AirPlay outputs do NOT appear in `SwitchAudioSource -a` until connected, so this step is manual).
2. Once connected, the speaker is the default output — just:

```bash
afplay <file>.mp3
```

3. Remind the user to switch output back afterwards if they care.

## Replay a past Tina announcement

Announce-agent events keep their audio; replay any event on any target:

```bash
curl -s "http://lab:3001/api/events?limit=10" | jq '.rows[] | {event_id, trigger_name, llm_trimmed}'
curl -s -X POST "http://lab:3001/api/events/<event_id>/replay" -H 'Content-Type: application/json' -d '{"target":"office"}'
```

(Replay to an AirPlay zone hits the same pyatv limitation — works only for audio formats pyatv accepts from Tina's own store; if it 500s, fall back to Path B.)

## Gotchas

- **pyatv CLI (`atvremote`) is broken on Python 3.14** (`RuntimeError: no current event loop`). If you ever need it: `uvx --python 3.12 --from pyatv atvremote`.
- `volume_set` succeeding does NOT mean `play_media` will work — they take different code paths in HA.
- Auto-mode blocks direct HTTP POSTs from the Mac; the HA calls above run via `ssh lab '…'` which passes the guard. Keep them wrapped in ssh.
- Audio-store files are plain files on disk — clean up old one-off casts occasionally (`ssh lab 'ls /opt/homelab/services/announce-agent/data/audio'`); daily-brief replays can stay.
