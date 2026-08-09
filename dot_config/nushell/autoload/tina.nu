# Tina — the house assistant, from the shell.
#
# One word = one intention. Nothing here needs `--help` to remember:
#
#   PYTASZ    tina "..."            zapytaj mózg, odpowiedź leci w domu
#             tina listen           zapytaj głosem, odpowiedź leci z Maca
#   MÓWISZ    tina announce "..."   powiedz dosłownie na głośnikach w domu
#             tina workflow <n>     odpal recepturę (pralka, kuweta, pogoda…)
#             tina replay <id>      zagraj ponownie to, co już powiedziała
#   PATRZYSZ  tina history          jej usta — co powiedziała i gdzie zagrało
#             tina brain            jej głowa — pytania, narzędzia, koszt
#             tina house            jej dom — co się wydarzyło u czujników
#
# Mnemonik dla podglądu: usta / głowa / dom. Trzy magazyny, trzy rzeczowniki.
#
# Two backends:
#   lab announce-agent (192.168.50.10:3001) — speakers
#     POST /say               literal text → ElevenLabs → HA play_media. Synchronous,
#                             returns what actually played. No generator involved.
#     POST /trigger/:name     recipes, and free text through the LLM via the
#                             `announce` recipe (rephrases, sometimes invents).
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
const JARVIS = "http://192.168.50.10:3002"

# Commands that were renamed. Kept as first-word intercepts inside `tina` rather
# than as real defs on purpose: a def would show up in `tina <TAB>` and in help,
# which is exactly the clutter this redesign removes. Only fires on a bare word
# (`tina log 5`), never inside a quoted question (`tina "log z dzisiaj"`).
const RETIRED = {
  ask: 'tina "..."'
  trigger: "tina workflow <nazwa>"
  log: "tina history"
  runs: "tina brain"
  events: "tina house"
}

# Ask the house something — the brain picks its own tools and answers out loud.
#
# Jarvis reaches only for what it needs (Homey state, history in VictoriaMetrics,
# the event log) and answers in two sentences. It says "nie mam odczytu" instead
# of inventing one.
#
# Knows: stan urządzeń, historia metryk od uruchomienia bazy, eventy domu, pogoda,
# psy, AGD, kurs dolara. Nie zna: niczego sprzed startu bazy metryk.
def tina [
  ...question: string               # o co pytasz (po polsku); bez argumentów → help
  --target (-t): string@"nu-complete tina-targets" = "auto"   # gdzie ma odpowiedzieć
  --dry (-d)                        # wypisz odpowiedź, nie odtwarzaj jej
] {
  if ($question | is-empty) {
    tina help
    return
  }

  let first = ($question | get -o 0 | default "")
  if $first in ($RETIRED | columns) {
    print -e $"tina: `tina ($first)` zmieniło nazwę — użyj `($RETIRED | get $first)`"
    return
  }

  let q = ($question | str join " " | str trim)
  if ($q | is-empty) {
    print -e 'tina: puste pytanie — `tina "jaka jest pogoda"`'
    return
  }

  let res = (
    http post --full --allow-errors --content-type application/json
      $"($JARVIS)/ask" { question: $q, target: $target, speak: (not $dry) }
  )
  if $res.status != 200 {
    print -e $"tina: ($JARVIS)/ask → HTTP ($res.status)"
    print -e ($res.body | to text)
    return
  }

  let body = $res.body
  print $"🗣  ($body.text)"
  tina-meta $body
  if $dry {
    print "   dry-run, nic nie zagrało"
  } else if ($body.spoken_on | is-empty) {
    print -e "   nic nie zagrało"
  } else {
    print $"   zagrało na: ($body.spoken_on | str join ', ')"
  }
}

# Say something on the house speakers, word for word.
#
# Literal by default — what you type is what she says, no LLM in the path. Text is
# joined from all bare args, so quoting is optional for simple messages.
def "tina announce" [
  ...msg: string                    # co ogłosić (po polsku)
  --target (-t): string@"nu-complete tina-targets" = "all"   # gdzie to zagrać
  --rephrase (-r)                   # niech LLM ubierze to w słowa (PRZEPISZE cię)
  --dry (-d)                        # nie odtwarzaj; z --rephrase pokaż jej wersję
] {
  let text = ($msg | str join " " | str trim)
  if ($text | is-empty) {
    print -e 'tina announce: nie ma czego ogłosić — `tina announce "paczki na dole"`'
    return
  }

  if $rephrase {
    tina-rephrased $text $target $dry
  } else {
    tina-literal $text $target $dry
  }
}

const LISTEN_MAX_SECONDS = 240        # ~4 min @ 16 kHz/16-bit mono — safe margin under /ask-audio's body limit
const LISTEN_MAX_AUDIO_BYTES = 8mb    # raw wav; base64 (+33%) still fits under the 12 MB limit
const MAC_VOICE = "Zosia"             # pl_PL voice that ships with macOS

# Ask by voice — record from the Mac mic, hear the answer from the Mac.
#
# Same brain as `tina "..."`, audio in instead of typed in (no STT, native Gemini
# audio). The answer comes back on your own speaker, so asking at 1am doesn't wake
# the house — pass `-t <zone>` when you do want it out loud in a room.
#
# Recording is your voice in your own house, so it's deleted right after the call
# unless you pass --keep. /ask-audio caps body at 12 MB (JSON + base64 audio) —
# about 4 minutes of 16 kHz/16-bit mono. Checked client-side so holding the hotkey
# too long gives a readable message instead of a bare HTTP 413.
def "tina listen" [
  --seconds (-s): int = 0                            # stała długość; 0 = stop na ciszy
  --target (-t): string@"nu-complete tina-targets"   # odpowiedz w domu zamiast na Macu
  --dry (-d)                                         # tylko wypisz, nie mów nigdzie
  --keep (-k)                                        # zostaw wav w $nu.temp-path
] {
  if $seconds > $LISTEN_MAX_SECONDS {
    print -e $"tina listen: -s ($seconds) za długo — limit ~($LISTEN_MAX_SECONDS) s, /ask-audio tnie body na 12 MB"
    return
  }

  if (which rec | is-empty) {
    print -e "tina listen: brak `rec` — zainstaluj sox: `brew install sox`"
    return
  }

  let wav = $"($nu.temp-path)/tina-listen-(random chars -l 6).wav"

  if $seconds > 0 {
    print $"🎙  nagrywam ($seconds) s..."
    ^rec -q -c 1 -r 16000 -b 16 $wav trim 0 $seconds
  } else {
    print "🎙  mów — kończę, gdy zamilkniesz (max 15 s)"
    # silence 1 0.1 3% 1 1.5 3% = start on sound, stop after 1.5 s of quiet
    ^rec -q -c 1 -r 16000 -b 16 $wav trim 0 15 silence 1 0.1 3% 1 1.5 3%
  }

  if not ($wav | path exists) {
    print -e "tina listen: nagranie nie wyszło — sprawdź `rec` i mikrofon"
    return
  }

  let size = (ls $wav | get 0.size)

  if $size < 4kb {
    print -e "tina listen: nic nie nagrałem — sprawdź mikrofon w Ustawieniach → Dźwięk"
    if not $keep { rm -f $wav }
    return
  }

  if $size > $LISTEN_MAX_AUDIO_BYTES {
    print -e $"tina listen: nagranie za duże — ($size), /ask-audio odrzuci je jako HTTP 413. Zmieść się w ~($LISTEN_MAX_SECONDS) s"
    if not $keep { rm -f $wav }
    return
  }

  # No -t → the house stays quiet and the Mac speaks; -t <zone> → the house speaks
  # and the Mac stays quiet. --dry silences both.
  let at_home = ((not $dry) and $target != null)

  let payload = (open --raw $wav | encode base64)
  let res = (
    http post --full --allow-errors --content-type application/json
      $"($JARVIS)/ask-audio"
      {
        audio_base64: $payload
        mime_type: "audio/wav"
        target: ($target | default "auto")
        speak: $at_home
      }
  )

  if $keep {
    print $"   nagranie zostaje: ($wav)"
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
  tina-meta $body

  if $dry {
    print "   dry-run, nic nie zagrało"
  } else if $at_home {
    if ($body.spoken_on? | default [] | is-empty) {
      print -e "   nic nie zagrało — sprawdź announce-agenta"
    } else {
      print $"   zagrało na: ($body.spoken_on | str join ', ')"
    }
  } else {
    tina-say $body.text
  }
}

# Fire a recipe on the announce-agent (pralka, kuweta, pogoda, faktury…).
#
# Waits for the recorded event, so you see what she actually said rather than a
# bare 202. TAB after the name lists every recipe the agent currently has.
def "tina workflow" [
  name: string@"nu-complete tina-workflows"          # nazwa receptury (TAB = lista)
  --target (-t): string@"nu-complete tina-targets"   # nadpisz cel z receptury
  --dry (-d)                                         # wygeneruj i wypisz, nic nie graj
  --params: record = {}                              # parametry, np. {kind: dinner}
] {
  let before = (tina-latest-id)
  mut body = { dry_run: $dry, params: $params }
  if $target != null { $body = ($body | insert target $target) }

  let res = (
    http post --full --allow-errors --content-type application/json
      $"($TINA)/trigger/($name)" $body
  )
  if $res.status != 202 {
    print -e $"tina workflow: ($name) → HTTP ($res.status)"
    print -e ($res.body | to text)
    return
  }

  let ev = (tina-await $before $name)
  if $ev == null {
    print -e $"tina workflow: brak eventu w 40 s — sprawdź ($TINA)/api/events"
    return
  }
  tina-print $ev $dry
}

# Play a past announcement again (id z `tina history`).
def "tina replay" [
  event_id: string@"nu-complete tina-history-ids"    # id z `tina history` (TAB = lista)
  --target (-t): string@"nu-complete tina-targets" = "all"
] {
  (
    http post --content-type application/json
      $"($TINA)/api/events/($event_id)/replay"
      { target: $target }
  )
}

# Her mouth — what Tina said out loud, where it played, and the id to replay it.
def "tina history" [
  n: int = 5
  --all (-a)     # dołóż ogłoszenia z receptur, nie tylko twoje własne
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

# Her head — brain runs: what it was asked, which tools it reached for, what it cost.
def "tina brain" [n: int = 10] {
  http get $"($JARVIS)/runs?limit=($n)"
  | get runs
  | select started_at trigger_kind input answer status cost_usd
}

# Her house — what actually happened at the sensors, from the Jarvis event log.
def "tina house" [--minutes (-m): int = 120] {
  http get $"($JARVIS)/events?minutes=($minutes)"
  | get events
  | select ts source type severity handled_action
}

# The tina cheat sheet, grouped by what you're trying to do.
def "tina help" [] {
  print "tina — asystentka domowa, ze skorupy. Jedno słowo = jedna intencja."
  print ""
  print "PYTASZ — pytasz ją o coś, ona odpowiada"
  print '  tina "jaka jest pogoda"        mózg dobiera narzędzia sam, odpowiedź leci w domu'
  print '  tina -d "..."                  odpowiedź na ekranie, nic nie gra'
  print '  tina -t office "..."           odpowiedz w jednej strefie zamiast `auto`'
  print "  tina listen                    zapytaj głosem — ODPOWIEDŹ Z GŁOŚNIKA MACA"
  print "  tina listen -t kitchen         …a jednak niech odpowie w domu"
  print "  tina listen -s 8               nagraj równo 8 s zamiast stopu na ciszy"
  print "  tina listen -k                 zostaw wav w $nu.temp-path"
  print ""
  print "MÓWISZ — każesz jej coś powiedzieć lub zrobić"
  print '  tina announce "paczki na dole" dosłownie, bez LLM — dokładnie twoje słowa'
  print '  tina announce -r "..."         niech LLM ubierze to w słowa (PRZEPISZE cię)'
  print '  tina announce -t livingroom    jedna strefa zamiast całego domu'
  print '  tina announce -d "..."         nie graj (z -r: pokaż jej wersję)'
  print "  tina workflow <nazwa>          odpal recepturę announce-agenta (TAB = lista)"
  print "  tina workflow meal --params {kind: dinner}"
  print "  tina replay <event_id>         zagraj ponownie (id z `tina history`)"
  print ""
  print "PATRZYSZ — usta, głowa, dom: trzy magazyny, trzy rzeczowniki"
  print "  tina history [n] [--all]       jej USTA — co powiedziała, gdzie zagrało, event_id"
  print "  tina brain [n]                 jej GŁOWA — pytania, narzędzia, koszt"
  print "  tina house [-m 120]            jej DOM — co się działo u czujników"
  print ""
  print "  tina help                      ten ekran (albo samo `tina`)"
  print ""
  print "Cele — wciśnij TAB po -t, każdy ma opis w menu:"
  print (nu-complete tina-targets)
  print ""
  print $"Backendy: ($TINA) — /say dosłownie · /trigger/:name recepturą"
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
    print -e $"tina announce: /say → HTTP ($res.status)"
    print -e ($res.body | to text)
    if $res.status == 404 {
      print -e "hint: brak /say — announce-agent jest starszy niż trasa dosłowna, przebuduj:"
      print -e "      ssh lab 'cd /opt/homelab/services/announce-agent && docker compose up -d --build'"
    }
    return
  }
  let body = $res.body
  print $"🔊 ($body.text)"
  if $dry {
    print $"   dry-run, nic nie zagrało  [($target)]"
  } else if ($body.played_on | is-empty) {
    print -e $"   nic nie zagrało — status ($body.status), powód ($body.silenced_reason)"
  } else {
    print $"   zagrało na: ($body.played_on | str join ', ')"
  }
}

# Through the LLM: /trigger is fire-and-forget, so wait for the recorded event.
def tina-rephrased [text: string, target: string, dry: bool] {
  let before = (tina-latest-id)
  let res = (
    http post --full --allow-errors --content-type application/json
      $"($TINA)/trigger/announce"
      { target: $target, dry_run: $dry, params: { msg: $text } }
  )
  if $res.status != 202 {
    print -e $"tina announce: /trigger/announce → HTTP ($res.status)"
    print -e ($res.body | to text)
    if ($res.body | to text | str contains "unknown trigger") {
      print -e "hint: receptura `announce` zniknęła — receptury siedzą w obrazie:"
      print -e "      ssh lab 'cd /opt/homelab/services/announce-agent && docker compose up -d --build'"
    }
    return
  }
  let ev = (tina-await $before "announce")
  if $ev == null {
    print -e $"tina announce: brak eventu w 40 s — sprawdź ($TINA)/api/events"
    return
  }
  tina-print $ev $dry
}

# Speak on the Mac's own speaker.
#
# `say` rather than fetching audio: /ask-audio with speak:false returns plain text
# and no audio, so playing it locally would need a second round trip to the
# announce-agent's TTS — an extra hop and ElevenLabs credits for something macOS
# already does offline, with a native pl_PL voice.
def tina-say [text: string] {
  if (which say | is-empty) {
    print -e "   (brak `say` — to nie macOS, odpowiedź została na ekranie)"
    return
  }
  let voice = (tina-mac-voice)
  if $voice == null {
    ^say $text
  } else {
    ^say -v $voice $text
  }
}

# Polish `say` voice, or null to let macOS fall back to its system default.
def tina-mac-voice [] {
  let voices = (
    ^say -v '?'
    | lines
    | parse -r '^(?<name>.+?)\s+(?<lang>[a-z]{2}_[A-Z]{2})'
    | where lang == "pl_PL"
    | get name
  )
  if ($voices | is-empty) { return null }
  if $MAC_VOICE in $voices { $MAC_VOICE } else { $voices | first }
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

# Recipe names, live from the agent. Tolerates both shapes the agent may return —
# bare strings today, records with a description if /triggers ever grows one — so
# the menu gains descriptions without a client change.
def "nu-complete tina-workflows" [] {
  let res = (http get --full --allow-errors $"($TINA)/triggers")
  if $res.status != 200 { return [] }
  $res.body
  | get -o triggers | default []
  | each {|t|
      if ($t | describe | str starts-with "record") {
        {
          value: ($t.name? | default ($t.id? | default ""))
          description: ($t.description? | default "receptura announce-agenta")
        }
      } else {
        { value: $t, description: "receptura announce-agenta" }
      }
    }
  | where value != ""
}

# event_ids of recent announcements, described by what Tina said. Hits the lab,
# so it is only wired to `tina replay` where you actually need it.
def "nu-complete tina-history-ids" [] {
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

# The one-line "how she got there" footer, shared by every brain path.
def tina-meta [body: record] {
  let tools = ($body.tools? | default [] | str join ', ')
  let cost = ($body.cost_usd? | default 0)
  print $"   ($body.style?  | default 'brain') · narzędzia: (if ($tools | is-empty) { 'brak' } else { $tools }) · $($cost)"
}

# Print a recorded event the same way for every path.
def tina-print [ev: record, dry: bool] {
  print $"🔊 ($ev.llm_trimmed)"
  if $dry {
    print $"   dry-run, nic nie zagrało  [($ev.target)]"
  } else if ($ev.played_on | is-empty) {
    print -e $"   nic nie zagrało — status ($ev.status), powód ($ev.silenced_reason?)"
  } else {
    print $"   zagrało na: ($ev.played_on | str join ', ')"
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
