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
  local ser prev spark
  ser=$("$JQ" -r '[.rates[].mid] | map(tostring) | join(" ")' <<< "$res" 2>/dev/null)
  prev=$(awk '{print $(NF-1)}' <<< "$ser")
  spark=$(awk '{n=split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █",b," "); mn=mx=$1; for(i=1;i<=NF;i++){if($i<mn)mn=$i; if($i>mx)mx=$i}; for(i=1;i<=NF;i++){k=(mx>mn)?int(($i-mn)/(mx-mn)*7)+1:4; printf "%s", b[k]}}' <<< "$ser")
  local color=overlay arrow=minus
  if [ -n "$prev" ]; then
    case $(awk -v r="$rate" -v p="$prev" 'BEGIN{print (r>p)?"up":(r<p)?"down":"flat"}') in
      up) color=green arrow=arrow.up;; down) color=red arrow=arrow.down;; esac
  fi
  "$JQ" -c --arg rate "$rate" --arg color "$color" --arg arrow "$arrow" --arg date "$date" --arg thr "$thr" --arg spark "$spark" --arg prev "$prev" --argjson e "$every" --arg ser "$ser" \
    '{item:{id:"pln-usd",text:":\($arrow)@\($color): \($rate)",icon:"dollarsign.circle",color:$color,expect:$e,
      tooltip:"USD = \($rate) PLN (NBP, \($date)). Previous day \($prev). Threshold \($thr).",
      menu:[{text:$spark,detail:"30 days"}]}}' <<< null
}
( while :; do poll; sleep "$every"; done ) & loop=$!
cat >/dev/null   # stdin ends: Gzyms is gone
kill $loop 2>/dev/null
