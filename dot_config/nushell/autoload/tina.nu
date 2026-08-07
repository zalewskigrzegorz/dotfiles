# Tina — announcements on the house speakers, from the shell.
#
# `tina "paczki na dole"`           → literal TTS, no LLM (default, exact wording)
# `tina --ai "..."`                 → let the LLM phrase it (it WILL rewrite you)
# `tina -t livingroom "..."`        → one zone
# `tina ask "jaka jest pogoda"`     → she answers out loud from live sensors
# `tina trigger washing_machine_done` → fire any announce-agent recipe
# `tina log` / `tina replay <id>` / `tina help`
#
# Two backends on the lab announce-agent (192.168.50.10:3001):
#   POST /say               literal text → ElevenLabs → HA play_media. Synchronous,
#                           returns what actually played. No generator involved.
#   POST /trigger/announce  free text through the LLM (recipe announce.yaml +
#                           prompt prompts/announce.md). Rephrases, sometimes
#                           invents — only use when you want it to sound composed.
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

# Ask about the house out loud — pogoda, co otwarte, co chodzi, gdzie są psy.
# Recipe `ask` fetches the whole sensor bundle every time; the prompt makes her
# answer only the question and add a second sentence only when a reading changes
# your decision (deszcz przy spacerze, płyta zostawiona przy wyjściu).
#
# Knows: pogoda + opady w najbliższej godzinie, PM2.5, temperatury, otwarte
# drzwi, AGD w trakcie, płyta/klima zostawione, gdzie psy są TERAZ, kuweta, waga
# Lucy. Nie zna historii — "czy psy wyszły dziś" jest poza zasięgiem, odpowie
# tylko, gdzie są w tej chwili.
def "tina ask" [
  ...question: string
  --target (-t): string@"nu-complete tina-targets" = "auto"
  --dry (-d)     # print the answer, don't play it
] {
  let q = ($question | str join " " | str trim)
  if ($q | is-empty) {
    print -e "tina ask: no question — `tina ask \"jaka jest pogoda\"`"
    return
  }
  tina trigger ask --target $target --dry=$dry --params { question: $q }
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

# Print the tina cheat sheet.
def "tina help" [] {
  print "tina — announcements on the house speakers"
  print ""
  print "  tina \"paczki na dole\"           say it verbatim (no LLM) — default"
  print "  tina --ai \"...\"                 let the LLM phrase it (it rewrites you)"
  print "  tina -t livingroom \"...\"         announce in one zone"
  print "  tina --dry \"...\"                 don't play (with --ai: print her draft)"
  print "  tina ask \"jaka jest pogoda\"      ask about the house, she answers out loud"
  print "  tina trigger <name>             fire a recipe (TAB for the list)"
  print "  tina log [n] [--all]            recent events"
  print "  tina replay <event_id>          replay a past event"
  print "  tina help                       this message"
  print ""
  print "Targets — hit TAB after -t, each one is described in the menu:"
  print (nu-complete tina-targets)
  print ""
  print $"Backend: ($TINA)  — /say literal · /trigger/:name via LLM"
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
