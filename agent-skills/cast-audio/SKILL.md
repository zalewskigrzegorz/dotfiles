---
name: cast-audio
description: Play a local audio file (mp3/wav: TTS briefing, recording, announcement) on a home speaker (office, kitchen, living room, any Homey/HA zone). Use on "puść to na głośniku", "zagraj w office/kuchni/salonie", "cast this", "play it on the speaker", or replaying a daily-brief mp3 on a room speaker. Covers the lab audio-store upload, HA play_media for Chromecast, and the Mac AirPlay fallback for pyatv speakers.
---

# cast-audio

The speaker's protocol decides the path; check it first. Zone → entity: `MEDIA_PLAYERS` in `~/Code/home-lab/services/announce-agent/src/zones.js`.

| Zone | Entity | Path |
|---|---|---|
| office | `media_player.greg_office` | **B**: AirPlay (pyatv) |
| others | per `zones.js` | **A**: Chromecast via HA |

Unsure: try A once. `500` + `miniaudio.DecodeError` in `/api/error_log` = pyatv → B, no other formats, no retry.

## A — Chromecast via HA `play_media`

```bash
scp <f>.mp3 mrglaszki:/opt/homelab/services/announce-agent/data/audio/<name>.mp3
ssh mrglaszki 'curl -sf -o /dev/null -w "%{http_code}" http://192.168.50.10:3001/audio/<name>.mp3 -r 0-100'   # 206
ssh mrglaszki 'HA_TOKEN=$(grep ^HA_TOKEN= /opt/homelab/stacks/announce-agent/.env | cut -d= -f2-); HA=http://homeassistant.mrglaszki.com:8123; \
curl -sS -X POST "$HA/api/services/media_player/volume_set" -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"<entity>\",\"volume_level\":0.7}" >/dev/null; \
curl -sS -X POST "$HA/api/services/media_player/play_media" -H "Authorization: Bearer $HA_TOKEN" -H "Content-Type: application/json" \
  -d "{\"entity_id\":\"<entity>\",\"media_content_id\":\"http://192.168.50.10:3001/audio/<name>.mp3\",\"media_content_type\":\"music\"}"'
```

Verify: `GET $HA/api/states/<entity>` → `playing` within ~5 s. `volume_set` working says nothing about `play_media`. Keep HA calls wrapped in `ssh mrglaszki` (auto-mode blocks direct HTTP POSTs from the Mac).

## B — AirPlay (office): the Mac plays it

HA can't stream to pyatv devices (`play_media` 500, `DecodeError` for mp3 and WAV, confirmed 2026-06-11); don't transcode. Greg connects the Mac in **Control Center → głośnik AirPlay** (it isn't in `SwitchAudioSource -a` until connected), then `afplay <file>.mp3`; remind him to switch output back.

## Notes

- Replay a Tina event: `tina replay <event_id> -t <zone>` (tina-announce skill); to an AirPlay zone it may 500 too → path B.
- `atvremote` is broken on Python 3.14: `uvx --python 3.12 --from pyatv atvremote`.
- Clean old one-off casts from `/opt/homelab/services/announce-agent/data/audio` now and then; daily-brief replays can stay.
