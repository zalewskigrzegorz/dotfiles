# Jarvis — mów do Maca, odpowiedź leci na głośniki w domu.
#
# `jarvis`            nagrywa aż ucichniesz (max 15 s), odpowiada na głos
# `jarvis -s 8`       nagrywa dokładnie 8 sekund
# `jarvis -d`         odpowiedź tylko na ekranie
# `jarvis -t office`  odpowiedź na konkretnym głośniku
# `jarvis -k`         zostaw nagranie w $nu.temp-path zamiast je kasować
#
# Ścieżka: mikrofon Maca → base64 → jarvis-brain /ask-audio (natywne audio
# Gemini, bez STT) → toole → /say. Sprzęt do pokoi to osobna sprawa (Faza 6).
#
# Nagranie to głos właściciela domu, więc kasujemy je zaraz po wywołaniu —
# chyba że poda się --keep (mirror `--keep` z tools/mic-test.mjs w jarvis-brain).
# /ask-audio ma limit body 12 MB (JSON + base64 audio), czyli maksymalnie ok.
# 4 minuty 16 kHz/16-bit mono. Sprawdzamy to po stronie klienta, żeby
# przytrzymanie hotkeya za długo dało czytelny komunikat zamiast gołego HTTP 413.

const JARVIS = "http://192.168.50.10:3002"
const MAX_SECONDS = 240        # ~4 min @ 16 kHz/16-bit mono — bezpieczny margines pod limit body /ask-audio
const MAX_AUDIO_BYTES = 8mb    # surowy wav; po base64 (+33%) mieści się pod limitem 12 MB

def jarvis [
  --seconds (-s): int = 0                                    # fixed length; 0 = stop on silence
  --target (-t): string@"nu-complete jarvis-targets" = "auto"
  --dry (-d)                                                 # print, don't speak
  --keep (-k)                                                # keep the wav in $nu.temp-path instead of deleting it
] {
  if $seconds > $MAX_SECONDS {
    print -e $"jarvis: -s ($seconds) za długo — limit ~($MAX_SECONDS) s, bo /ask-audio ma body 12 MB"
    return
  }

  if (which rec | is-empty) {
    print -e "jarvis: `rec` nie znalezione — zainstaluj sox: `brew install sox`"
    return
  }

  let wav = $"($nu.temp-path)/jarvis-(random chars -l 6).wav"

  if $seconds > 0 {
    print $"🎙  nagrywam ($seconds) s..."
    ^rec -q -c 1 -r 16000 -b 16 $wav trim 0 $seconds
  } else {
    print "🎙  mów — kończę, gdy ucichniesz (max 15 s)"
    # silence 1 0.1 3% 1 1.5 3% = start on sound, stop after 1.5 s of quiet
    ^rec -q -c 1 -r 16000 -b 16 $wav trim 0 15 silence 1 0.1 3% 1 1.5 3%
  }

  if not ($wav | path exists) {
    print -e "jarvis: nagrywanie nie powiodło się — sprawdź `rec` i mikrofon"
    return
  }

  let size = (ls $wav | get 0.size)

  if $size < 4kb {
    print -e "jarvis: nic nie nagrałem — sprawdź mikrofon w Ustawieniach → Dźwięk"
    if not $keep { rm -f $wav }
    return
  }

  if $size > $MAX_AUDIO_BYTES {
    print -e $"jarvis: nagranie za duże — ($size), /ask-audio odrzuci to jako HTTP 413. Trzymaj się krócej niż ~($MAX_SECONDS) s"
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
    print $"   nagranie zostawione: ($wav)"
  } else {
    rm -f $wav
  }

  if $res.status != 200 {
    print -e $"jarvis: HTTP ($res.status)"
    print -e ($res.body | to text)
    return
  }

  let body = $res.body
  print $"🗣  ($body.text)"
  let tools = ($body.tools? | default [] | str join ', ')
  print $"   ($body.style) · tools: (if ($tools | is-empty) { 'brak' } else { $tools })"
  if (not $dry) and ($body.spoken_on | is-empty) {
    print -e "   nic nie zagrało — sprawdź announce-agenta"
  }
}

# Targets for `-t`. Duplicated from `nu-complete tina-targets` (tina.nu) on
# purpose: nushell's autoload sources each file in the directory separately, in
# filename order, and "jarvis.nu" sorts before "tina.nu" — a completer that
# reaches across files that way is an `unknown_command` parse error on every
# new terminal (confirmed empirically). Keep in sync with `nu-complete
# tina-targets` in tina.nu / `MEDIA_PLAYERS` in
# lab:/opt/homelab/services/announce-agent/src/zones.js.
def "nu-complete jarvis-targets" [] {
  [
    { value: "all",        description: "cały dom — biuro + kuchnia + salon" }
    { value: "auto",       description: "wg obecności telefonów, ścisza się w nocy" }
    { value: "office",     description: "biuro, AirPlay (greg_office)" }
    { value: "kitchen",    description: "kuchnia (Nest), fallback → kominek" }
    { value: "livingroom", description: "salon / kominek (fireplace), fallback → Nest" }
  ]
}
