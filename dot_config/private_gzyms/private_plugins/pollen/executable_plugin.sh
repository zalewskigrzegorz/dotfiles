#!/bin/bash
# Pollen from the Homey device "Pylenie". Homey ID and token come from the plugin options (config.toml). Bash 3.2, curl, jq.
JQ="$(command -v jq || echo /usr/bin/jq)"
every="${GZYMS_OPT_EVERY:-1800}"; case "$every" in ''|*[!0-9]*|0) every=1800;; esac
alert="${GZYMS_OPT_ALERT_LEVEL:-wysokie}"
DEV=3b80d707-9a7c-430e-ad8d-bf347a37acbd
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/gzyms/pollen.hit"; mkdir -p "$(dirname "$CACHE")"
# rank of a level word; the pill is the highest of the pollen allergens (moulds only in the menu)
read -r -d '' PROG <<'JQ'
def rank: {"bardzo niskie":0,"niskie":1,"średnie":2,"wysokie":3,"bardzo wysokie":4}[.] // 0;
. as $d | def val($k): $d.capabilitiesObj["measure_generic.\($k)"].value // "?";
(["trawy","pokrzywa","babka","szczaw","sosna"]) as $p | (["alternaria","cladosporium"]) as $m
| [$p[] | {n: ., v: val(.)}] as $pp | [$m[] | {n: ., v: val(.)}] as $mm
| ($pp | max_by(.v | rank)) as $top
| {level: $top.v, rank: ($top.v | rank), who: $top.n, pp: $pp, mm: $mm}
JQ
poll() {
  local hid tok res out lvl rank who color hit
  hid="$GZYMS_OPT_HOMEY_ID"; tok="$GZYMS_OPT_HOMEY_TOKEN"
  [ -n "$hid" ] && [ -n "$tok" ] && res=$(curl -fsS --max-time 20 -H "Authorization: Bearer $tok" "https://$hid.connect.athom.com/api/manager/devices/device/$DEV" 2>/dev/null)
  out=$("$JQ" -c "$PROG" <<< "$res" 2>/dev/null)
  if [ -z "$out" ]; then
    echo "{\"item\":{\"id\":\"pollen\",\"text\":\"pollen ?\",\"icon\":\"leaf\",\"expect\":$every,\"error\":\"Homey did not answer. Set Homey ID and token in Settings → Plugins → Pollen, or check the network. Trying again in a while.\"}}"
    return
  fi
  lvl=$("$JQ" -r .level <<< "$out"); rank=$("$JQ" -r .rank <<< "$out"); who=$("$JQ" -r .who <<< "$out")
  case "$alert" in "bardzo wysokie") min=4;; "średnie") min=2;; *) min=3;; esac
  hit=0; [ "$rank" -ge "$min" ] && hit=1
  if [ "$hit" = 1 ] && [ "$(cat "$CACHE" 2>/dev/null)" != 1 ]; then
    echo "{\"notify\":{\"id\":\"pollen-alert\",\"title\":\"Pollen: $lvl\",\"body\":\"Highest: $who.\",\"level\":\"warning\",\"sound\":\"message\"}}"
  fi
  echo "$hit" > "$CACHE"
  case "$rank" in 0|1) color=green;; 2) color=gold;; 3) color=peach;; *) color=red;; esac
  "$JQ" -c --arg lvl "$lvl" --arg who "$who" --arg c "$color" --argjson e "$every" \
    '{item:{id:"pollen",text:$lvl,icon:"leaf",color:$c,expect:$e,tooltip:"Highest pollen: \($who), \($lvl) (Homey, Pylenie)",
      menu:([.pp[]|{tag:"pollen",text:.n,detail:.v}] + [{separator:true}] + [.mm[]|{tag:"mold",text:.n,detail:.v}])}}' <<< "$out"
}
( while :; do poll; sleep "$every"; done ) & loop=$!
cat >/dev/null
kill $loop 2>/dev/null
