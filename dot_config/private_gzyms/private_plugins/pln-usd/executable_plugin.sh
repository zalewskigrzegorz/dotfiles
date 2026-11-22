#!/bin/bash
# PLN/USD from the public NBP API (no key): the last 30 mid rates give the rate, the trend and the chart. Bash 3.2, curl, jq.
JQ="$(command -v jq || echo /usr/bin/jq)"
every="${GZYMS_OPT_EVERY:-3600}"; case "$every" in ''|*[!0-9]*|0) every=3600;; esac
thr="${GZYMS_OPT_THRESHOLD:-4.0}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/gzyms/pln-usd.side"; mkdir -p "$(dirname "$CACHE")"
URL='https://api.nbp.pl/api/exchangerates/rates/a/usd/last/30/?format=json'
poll() {
  local res rate date side prev
  res=$(curl -fsS --max-time 20 "$URL" 2>/dev/null)
  rate=$("$JQ" -r '.rates[-1].mid // empty' <<< "$res" 2>/dev/null)
  date=$("$JQ" -r '.rates[-1].effectiveDate // empty' <<< "$res" 2>/dev/null)
  if [ -z "$rate" ]; then
    echo "{\"item\":{\"id\":\"pln-usd\",\"text\":\"USD ?\",\"icon\":\"dollarsign.circle\",\"expect\":$every,\"error\":\"NBP did not answer. Check the network. Trying again in a while.\"}}"
    return
  fi
  side=$(awk -v r="$rate" -v t="$thr" 'BEGIN{print (r>=t)?"above":"below"}')
  prev=$(cat "$CACHE" 2>/dev/null)
  if [ -n "$prev" ] && [ "$prev" != "$side" ]; then
    echo "{\"notify\":{\"id\":\"pln-usd-cross\",\"title\":\"USD crossed $thr PLN\",\"body\":\"Now $rate PLN ($side the threshold).\",\"level\":\"warning\",\"sound\":\"message\"}}"
  fi
  echo "$side" > "$CACHE"
  local prev
  prev=$("$JQ" -r '.rates[-2].mid // empty' <<< "$res" 2>/dev/null)
  local color=overlay arrow=minus
  if [ -n "$prev" ]; then
    case $(awk -v r="$rate" -v p="$prev" 'BEGIN{print (r>p)?"up":(r<p)?"down":"flat"}') in
      up) color=green arrow=arrow.up;; down) color=red arrow=arrow.down;; esac
  fi
  # The popup: the rate with its change over 1, 7 and 30 days, the 30 rates as a chart with the threshold, min, max and average.
  "$JQ" -c --arg color "$color" --arg arrow "$arrow" --arg thr "$thr" --argjson e "$every" '
    def r4: . * 10000 | round / 10000;
    def day: strptime("%Y-%m-%d") | mktime | strftime("%e %b") | ltrimstr(" ");
    [.rates[].mid] as $v | [.rates[].effectiveDate] as $d | $v[-1] as $r | ($thr | tonumber? // null) as $t
    | def ch($n; $l): ($r - $v[-1 - $n] | r4) as $x
        | {label: $l, text: ((if $x > 0 then "+" else "" end) + ($x | tostring)), color: (if $x > 0 then "green" elif $x < 0 then "red" else "overlay" end)};
    {item: {id: "pln-usd", text: ":\($arrow)@\($color): \($r)", icon: "dollarsign.circle", color: $color, expect: $e,
      tooltip: "USD = \($r) PLN (NBP, \($d[-1])). Previous day \($v[-2]). Threshold \($thr).",
      menu: [
        {value: "\($r)", color: $color, unit: "PLN per USD · NBP, \($d[-1] | day)",
         deltas: [ch(1; "1 d"), ch(5; "7 d"), ch(($v | length) - 1; "30 d")]},
        {chart: ({values: $v, labels: [$d[] | day], color: "sky"} + (if $t then {line: {value: $t, label: "threshold"}} else {} end))},
        {stats: [{label: "min", value: ($v | min | tostring)}, {label: "max", value: ($v | max | tostring)},
                 {label: "avg", value: ($v | add / length | r4 | tostring)}]}]}}' <<< "$res"
}
( while :; do poll; sleep "$every"; done ) & loop=$!
cat >/dev/null   # stdin ends: Gzyms is gone
kill $loop 2>/dev/null
