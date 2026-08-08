# Tina — everything for the house assistant, from the shell.
#
# One command, grouped by what you're trying to do (see `tina help` at 1am):
#   pytanie    tina ask "..."          / tina ask --legacy "..."
#   głos       tina listen             push-to-talk from the Mac mic
#   ogłoszenie tina "..."              / tina --ai "..." / tina trigger <recipe>
#   podgląd    tina runs / tina events / tina log / tina replay <id>
#
# Two backends:
#   lab announce-agent (192.168.50.10:3001) — speakers
#     POST /say               literal text → ElevenLabs → HA play_media. Synchronous,
#                             returns what actually played. No generator involved.
#     POST /trigger/announce  free text through the LLM (recipe announce.yaml +
#                             prompt prompts/announce.md). Rephrases, sometimes
#                             invents — only use when you want it to sound composed.
#   lab jarvis-brain (192.168.50.10:3002) — the brain
#     POST /ask               text question, tool-calling (Gemini)
#     POST /ask-audio         base64 wav in, same tool-calling, used by `tina listen`
#     GET  /runs, /events     observability
#
# Targets come from `MEDIA_PLAYERS` in
# lab:/opt/homelab/services/announce-agent/src/zones.js:
#   all         → greg_office + nest (kitchen) + fireplace (salon), whole house
#   office      → greg_office (AirPlay)
#   kitchen     → nest, falls back to fireplace
#   livingroom  → fireplace, falls back to nest
#   auto        → presence-based (phones), night-mode aware

const TINA = "http://192.168.50.10:3001"

# Announce something on the house speakers. Text is joined from all bare args,
# so quoting is optional for simple messages. Literal by default — what you type
# is what she says.
def tina [
  ...msg: string                    # what to announce (Polish)
  --target (-t): string@"nu-complete tina-targets" = "all"   # where to play it
  --ai                              # phrase it with the LLM instead of verbatim
  --dry (-d)                        # don't play; with --ai also prints her draft
] {
  let text = ($msg | str join " " | str trim)
  if ($text | is-empty) {
    print -e "tina: nothing to announce — `tina \"paczki na dole\"`"
    return
  }

  if $ai {
    tina-generated $text $target $dry
  } else {
    tina-literal $text $target $dry
  }
}

const JARVIS = "http://192.168.50.10:3002"

# Ask about the house — Jarvis picks the tools it needs (Homey state, history in
# VictoriaMetrics, the event log) and answers in two sentences. Unlike the old
# path it does NOT fetch everything every time, and it says "nie mam odczytu"
# instead of inventing one.
#
# Knows: stan urządzeń, historia metryk od uruchomienia bazy, eventy domu,
# pogoda, psy, AGD, kurs dolara. Nie zna: niczego sprzed startu bazy metryk.
def "tina ask" [
  ...question: string
  --target (-t): string@"nu-complete tina-targets" = "auto"
  --dry (-d)       # print the answer, don't play it
  --legacy         # old announce-agent recipe path (Bielik + 21 fetchy)
] {
  let q = ($question | str join " " | str trim)
  if ($q | is-empty) {
    print -e "tina ask: no question — `tina ask \"jaka jest pogoda\"`"
    return
  }

  if $legacy {
    tina trigger ask --target $target --dry=$dry --params { question: $q }
    return
  }

  let res = (
    http post --full --allow-errors --content-type application/json
      $"($JARVIS)/ask" { question: $q, target: $target, speak: (not $dry) }
  )
  if $res.status != 200 {
    print -e $"tina ask: ($JARVIS)/ask → HTTP ($res.status)"
    print -e ($res.body | to text)
    return
  }

  let body = $res.body
  print $"🗣  ($body.text)"
  let tools = ($body.tools? | default [] | str join ', ')
  print $"   ($body.style) · tools: (if ($tools | is-empty) { 'brak' } else { $tools }) · $($body.cost_usd? | default 0)"
  if $dry {
    print "   dry-run, nothing played"
  } else if ($body.spoken_on | is-empty) {
    print -e "   nothing played"
  } else {
    print $"   played on: ($body.spoken_on | str join ', ')"
  }
}

const LISTEN_MAX_SECONDS = 240        # ~4 min @ 16 kHz/16-bit mono — safe margin under /ask-audio's body limit
const LISTEN_MAX_AUDIO_BYTES = 8mb    # raw wav; base64 (+33%) still fits under the 12 MB limit

# Push-to-talk: record from the Mac mic, send to the brain, hear the answer on
# the house speakers. Mirrors `tina ask` but audio-in instead of typed-in —
# same /ask-audio endpoint, no STT, native Gemini audio.
#
# Recording is your voice in your own house, so it's deleted right after the
# call unless you pass --keep (mirrors `--keep` in tools/mic-test.mjs in
# jarvis-brain). /ask-audio caps body at 12 MB (JSON + base64 audio) — about 4
# minutes of 16 kHz/16-bit mono. Checked client-side so holding the hotkey too
# long gives a readable message instead of a bare HTTP 413.
def "tina listen" [
  --seconds (-s): int = 0                                    # fixed length; 0 = stop on silence
  --target (-t): string@"nu-complete tina-targets" = "auto"
  --dry (-d)                                                 # print, don't speak
  --keep (-k)                                                # keep the wav in $nu.temp-path instead of deleting it
] {
  if $seconds > $LISTEN_MAX_SECONDS {
    print -e $"tina listen: -s ($seconds) too long — limit ~($LISTEN_MAX_SECONDS) s, /ask-audio has a 12 MB body cap"
    return
  }

  if (which rec | is-empty) {
    print -e "tina listen: `rec` not found — install sox: `brew install sox`"
    return
  }

  let wav = $"($nu.temp-path)/tina-listen-(random chars -l 6).wav"

  if $seconds > 0 {
    print $"🎙  recording ($seconds) s..."
    ^rec -q -c 1 -r 16000 -b 16 $wav trim 0 $seconds
  } else {
    print "🎙  talk — stops after you go quiet (max 15 s)"
    # silence 1 0.1 3% 1 1.5 3% = start on sound, stop after 1.5 s of quiet
    ^rec -q -c 1 -r 16000 -b 16 $wav trim 0 15 silence 1 0.1 3% 1 1.5 3%
  }

  if not ($wav | path exists) {
    print -e "tina listen: recording failed — check `rec` and the mic"
    return
  }

  let size = (ls $wav | get 0.size)

  if $size < 4kb {
    print -e "tina listen: nothing recorded — check the mic in System Settings → Sound"
    if not $keep { rm -f $wav }
    return
  }

  if $size > $LISTEN_MAX_AUDIO_BYTES {
    print -e $"tina listen: recording too large — ($size), /ask-audio would reject it as HTTP 413. Stay under ~($LISTEN_MAX_SECONDS) s"
    if not $keep { rm -f $wav }
    return
  }

  let payload = (open --raw $wav | encode base64)
  let res = (
    http post --full --allow-errors --content-type application/json
      $"($JARVIS)/ask-audio"
      { audio_base64: $payload, mime_type: "audio/wav", target: $target, speak: (not $dry) }
  )

  if $keep {
    print $"   recording kept: ($wav)"
  } else {
    rm -f $wav
  }

  if $res.status != 200 {
    print -e $"tina listen: HTTP ($res.status)"
    print -e ($res.body | to text)
    return
  }

  let body = $res.body
  print $"🗣  ($body.text)"
  let tools = ($body.tools? | default [] | str join ', ')
  print $"   ($body.style) · tools: (if ($tools | is-empty) { 'brak' } else { $tools })"
  if (not $dry) and ($body.spoken_on | is-empty) {
    print -e "   nothing played — check the announce-agent"
  }
}

# Recent brain runs — what it was asked, which tools it reached for, what it cost.
def "tina runs" [n: int = 10] {
  http get $"($JARVIS)/runs?limit=($n)"
  | get runs
  | select started_at trigger_kind input answer status cost_usd
}

# Recent house events from the Jarvis event log.
def "tina events" [--minutes (-m): int = 120] {
  http get $"($JARVIS)/events?minutes=($minutes)"
  | get events
  | select ts source type severity handled_action
}

# Fire any announce-agent recipe (pralka, kuweta, pogoda, faktury, ...). Waits
# for the event so you see what she actually said.
def "tina trigger" [
  name: string@"nu-complete tina-triggers"
  --target (-t): string@"nu-complete tina-targets"   # override the recipe's own target
  --dry (-d)                                         # generate + print, play nothing
  --params: record = {}                              # recipe params, e.g. {kind: dinner}
] {
  let before = (tina-latest-id)
  mut body = { dry_run: $dry, params: $params }
  if $target != null { $body = ($body | insert target $target) }

  let res = (
    http post --full --allow-errors --content-type application/json
      $"($TINA)/trigger/($name)" $body
  )
  if $res.status != 202 {
    print -e $"tina: ($name) → HTTP ($res.status)"
    print -e ($res.body | to text)
    return
  }

  let ev = (tina-await $before $name)
  if $ev == null {
    print -e $"tina: no event within 40s — check ($TINA)/api/events"
    return
  }
  tina-print $ev $dry
}

# Recent events — the spoken line and where it landed. `--all` includes the
# recipe-driven ones (pralka, posiłki), otherwise just your own announcements.
def "tina log" [
  n: int = 5
  --all (-a)     # include recipe-driven events, not just say/announce
] {
  let rows = (
    http get $"($TINA)/api/events?limit=($n * 6)"
    | get rows
  )
  let filtered = if $all { $rows } else {
    $rows | where trigger_name in ["say" "announce"]
  }
  $filtered
  | first $n
  | select ts trigger_name status dry_run llm_trimmed played_on event_id
}

# Replay a past announcement's audio on a target (event_id from `tina log`).
def "tina replay" [
  event_id: string@"nu-complete tina-events"
  --target (-t): string@"nu-complete tina-targets" = "all"
] {
  (
    http post --content-type application/json
      $"($TINA)/api/events/($event_id)/replay"
      { target: $target }
  )
}

# Print the tina cheat sheet, grouped by what you're trying to do.
def "tina help" [] {
  print "tina — the house assistant, from the shell"
  print ""
  print "PYTANIE — ask the house something, she answers out loud"
  print "  tina ask \"jaka jest pogoda\"      tool-calling (Gemini), knows devices/history/events"
  print "  tina ask --legacy \"...\"          old path — Bielik + 21 fetches, slower"
  print ""
  print "GŁOS — push-to-talk from the Mac mic (no typing)"
  print "  tina listen                     record until you go quiet (max 15 s), speak the answer"
  print "  tina listen -s 8                record exactly 8 s instead of stop-on-silence"
  print "  tina listen -d                  answer on screen only, don't play it"
  print "  tina listen -t office            answer on one speaker instead of `auto`"
  print "  tina listen -k                  keep the wav in $nu.temp-path instead of deleting it"
  print ""
  print "OGŁOSZENIE — say something on the speakers"
  print "  tina \"paczki na dole\"           say it verbatim (no LLM) — default, exact wording"
  print "  tina --ai \"...\"                 let the LLM phrase it (it WILL rewrite you)"
  print "  tina -t livingroom \"...\"         announce in one zone instead of the whole house"
  print "  tina --dry \"...\"                don't play (with --ai: print her draft instead)"
  print "  tina trigger <name>             fire an announce-agent recipe (TAB for the list)"
  print ""
  print "PODGLĄD — what she said, what it cost, what happened in the house"
  print "  tina runs [n]                   recent brain runs — asked, tools used, cost"
  print "  tina events [-m 120]            house events from the last N minutes"
  print "  tina log [n] [--all]            recent spoken events, --all includes recipes"
  print "  tina replay <event_id>          replay a past event's audio (id from `tina log`)"
  print ""
  print "  tina help                       this message"
  print ""
  print "Targets — hit TAB after -t, each one is described in the menu:"
  print (nu-complete tina-targets)
  print ""
  print $"Backends: ($TINA) — /say literal · /trigger/:name via LLM"
  print $"          ($JARVIS) — /ask, /ask-audio, /runs, /events"
}

# --- paths -------------------------------------------------------------------

# Verbatim: POST /say is synchronous and reports what played, so no polling.
def tina-literal [text: string, target: string, dry: bool] {
  let res = (
    http post --full --allow-errors --content-type application/json
      $"($TINA)/say" { text: $text, target: $target, dry_run: $dry }
  )
  if $res.status != 200 {
    print -e $"tina: /say → HTTP ($res.status)"
    print -e ($res.body | to text)
    if $res.status == 404 {
      print -e "hint: /say missing — announce-agent predates the literal route, rebuild it:"
      print -e "      ssh lab 'cd /opt/homelab/services/announce-agent && docker compose up -d --build'"
    }
    return
  }
  let body = $res.body
  print $"🔊 ($body.text)"
  if $dry {
    print $"   dry-run, nothing played  [($target)]"
  } else if ($body.played_on | is-empty) {
    print -e $"   nothing played — status ($body.status), reason ($body.silenced_reason)"
  } else {
    print $"   played on: ($body.played_on | str join ', ')"
  }
}

# Through the LLM: /trigger is fire-and-forget, so wait for the recorded event.
def tina-generated [text: string, target: string, dry: bool] {
  let before = (tina-latest-id)
  let res = (
    http post --full --allow-errors --content-type application/json
      $"($TINA)/trigger/announce"
      { target: $target, dry_run: $dry, params: { msg: $text } }
  )
  if $res.status != 202 {
    print -e $"tina: /trigger/announce → HTTP ($res.status)"
    print -e ($res.body | to text)
    if ($res.body | to text | str contains "unknown trigger") {
      print -e "hint: the `announce` recipe is gone — recipes live inside the image:"
      print -e "      ssh lab 'cd /opt/homelab/services/announce-agent && docker compose up -d --build'"
    }
    return
  }
  let ev = (tina-await $before "announce")
  if $ev == null {
    print -e $"tina: no event within 40s — check ($TINA)/api/events"
    return
  }
  tina-print $ev $dry
}

# --- completions -------------------------------------------------------------

# Targets for `-t`. Static on purpose — the announce-agent has no /zones
# endpoint, and tab-completion should not wait on the network. Keep in sync with
# `MEDIA_PLAYERS` in lab:/opt/homelab/services/announce-agent/src/zones.js.
def "nu-complete tina-targets" [] {
  [
    { value: "all",        description: "cały dom — biuro + kuchnia + salon" }
    { value: "auto",       description: "wg obecności telefonów, ścisza się w nocy" }
    { value: "office",     description: "biuro, AirPlay (greg_office)" }
    { value: "kitchen",    description: "kuchnia (Nest), fallback → kominek" }
    { value: "livingroom", description: "salon / kominek (fireplace), fallback → Nest" }
  ]
}

# Recipe names, live from the agent.
def "nu-complete tina-triggers" [] {
  let res = (http get --full --allow-errors $"($TINA)/triggers")
  if $res.status != 200 { return [] }
  $res.body | get -o triggers | default []
}

# event_ids of recent announcements, described by what Tina said. Hits the lab,
# so it is only wired to `tina replay` where you actually need it.
def "nu-complete tina-events" [] {
  let res = (http get --full --allow-errors $"($TINA)/api/events?limit=25")
  if $res.status != 200 { return [] }
  $res.body
  | get -o rows | default []
  | where dry_run == false
  | each {|r|
      {
        value: $r.event_id
        description: $"($r.ts | into datetime | format date '%d.%m %H:%M') ($r.trigger_name) — ($r.llm_trimmed | default '' | str substring 0..50)"
      }
    }
}

# --- internals ---------------------------------------------------------------

# Print a recorded event the same way for every path.
def tina-print [ev: record, dry: bool] {
  print $"🔊 ($ev.llm_trimmed)"
  if $dry {
    print $"   dry-run, nothing played  [($ev.target)]"
  } else if ($ev.played_on | is-empty) {
    print -e $"   nothing played — status ($ev.status), reason ($ev.silenced_reason?)"
  } else {
    print $"   played on: ($ev.played_on | str join ', ')"
  }
}

# event_id of the newest event, or null when the store is empty/unreachable.
def tina-latest-id [] {
  let res = (http get --full --allow-errors $"($TINA)/api/events?limit=1")
  if $res.status != 200 { return null }
  $res.body | get -o rows | default [] | get -o 0.event_id
}

# Poll the event store until an event for $trigger newer than $before shows up.
def tina-await [before: any, trigger: string] {
  for _ in 1..40 {
    sleep 1sec
    let row = (
      http get --allow-errors $"($TINA)/api/events?limit=1"
      | get -o rows | default [] | get -o 0
    )
    if $row != null and $row.event_id != $before and $row.trigger_name == $trigger {
      return $row
    }
  }
  null
}
