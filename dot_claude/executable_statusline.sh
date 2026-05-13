#!/usr/bin/env bash
# Claude Code statusline.
# Bars show % of period ELAPSED (visual countdown), text shows time-to-reset.
# Reset times come from `/usage` — set them in settings.json env:
#
#   "CLAUDE_WEEKLY_RESET":        "2026-05-17T04:00"   # ISO local, auto-rolls +7d
#   "CLAUDE_SESSION_RESET":       ""                   # leave empty; ccusage auto-detects
#   "CLAUDE_SONNET_WEEKLY_RESET": ""                   # optional ISO local
#
# Re-run /usage and update CLAUDE_WEEKLY_RESET when it changes.

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "claude"')
dur_ms=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // 0')
added=$(printf '%s' "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // 0')
over200k=$(printf '%s' "$input" | jq -r '.exceeds_200k_tokens // false')
style=$(printf '%s' "$input" | jq -r '.output_style.name // ""')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // ""')

mm=$(( dur_ms / 60000 )); ss=$(( (dur_ms % 60000) / 1000 ))
dur_fmt=$(printf '%dm%02ds' "$mm" "$ss")

# --- palette (Dracula Pro — readable on #22212C bg) ---
B=$'\033[1m'
N=$'\033[0m'
FG=$'\033[38;2;248;248;242m'      # foreground         #F8F8F2
LABEL=$'\033[38;2;149;128;255m'   # purple label       #9580FF
MUTED=$'\033[38;2;198;198;194m'   # dim foreground     #C6C6C2
SEPC=$'\033[38;2;121;112;169m'    # separator/cursor   #7970A9
TROUGH=$'\033[38;2;69;65;88m'     # bar empty (track)  #454158
ACCENT=$'\033[38;2;128;255;234m'  # cyan               #80FFEA
G=$'\033[38;2;138;255;128m'       # green              #8AFF80
Y=$'\033[38;2;255;255;128m'       # yellow             #FFFF80
O=$'\033[38;2;255;202;128m'       # orange             #FFCA80
R=$'\033[38;2;255;149;128m'       # red                #FF9580
PINK=$'\033[38;2;255;128;191m'    # pink               #FF80BF
SEP=" ${SEPC}·${N} "

now_ts=$(date +%s)

# --- ccusage cache (30s) — session block auto-detect ---
cache_dir="${TMPDIR:-/tmp}/claude-statusline-$UID"
mkdir -p "$cache_dir" 2>/dev/null
cache_file="$cache_dir/ccusage.json"
if [ -f "$cache_file" ]; then
  mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null || echo 0)
  age=$(( now_ts - mtime ))
else
  age=9999
fi
if [ "$age" -gt 30 ] && command -v ccusage >/dev/null 2>&1; then
  ccusage blocks --json --active --offline 2>/dev/null | jq '.blocks[0] // null' > "$cache_file.tmp" 2>/dev/null \
    && mv "$cache_file.tmp" "$cache_file"
fi

# --- session reset ---
sess_start_ts=0; sess_end_ts=0
if [ -n "${CLAUDE_SESSION_RESET:-}" ]; then
  sess_end_ts=$(date -j -f "%Y-%m-%dT%H:%M" "$CLAUDE_SESSION_RESET" +%s 2>/dev/null \
             || date -d "$CLAUDE_SESSION_RESET" +%s 2>/dev/null || echo 0)
  sess_start_ts=$(( sess_end_ts - 18000 ))
elif [ -f "$cache_file" ]; then
  s=$(jq -r '.startTime // ""' "$cache_file" 2>/dev/null)
  e=$(jq -r '.endTime   // ""' "$cache_file" 2>/dev/null)
  [ -n "$s" ] && [ "$s" != "null" ] && sess_start_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "${s%.*}" +%s 2>/dev/null || date -u -d "$s" +%s 2>/dev/null || echo 0)
  [ -n "$e" ] && [ "$e" != "null" ] && sess_end_ts=$(date -j -u -f "%Y-%m-%dT%H:%M:%S"   "${e%.*}" +%s 2>/dev/null || date -u -d "$e" +%s 2>/dev/null || echo 0)
fi

# --- weekly reset (auto-roll +7d) ---
roll_weekly() {
  local raw=$1
  local t=$(date -j -f "%Y-%m-%dT%H:%M" "$raw" +%s 2>/dev/null \
         || date -d "$raw" +%s 2>/dev/null || echo 0)
  [ "$t" -eq 0 ] && { echo 0; return; }
  while [ "$t" -le "$now_ts" ]; do t=$(( t + 7 * 86400 )); done
  echo "$t"
}
week_end_ts=0; week_start_ts=0
if [ -n "${CLAUDE_WEEKLY_RESET:-}" ]; then
  week_end_ts=$(roll_weekly "$CLAUDE_WEEKLY_RESET")
  week_start_ts=$(( week_end_ts - 7 * 86400 ))
fi

sonnet_end_ts=0; sonnet_start_ts=0
if [ -n "${CLAUDE_SONNET_WEEKLY_RESET:-}" ]; then
  sonnet_end_ts=$(roll_weekly "$CLAUDE_SONNET_WEEKLY_RESET")
  sonnet_start_ts=$(( sonnet_end_ts - 7 * 86400 ))
fi

# --- helpers ---
pct_elapsed() {
  local start=$1 end=$2
  [ "$end" -le "$start" ] && { echo 0; return; }
  local total=$(( end - start ))
  local done=$(( now_ts - start ))
  (( done < 0 )) && done=0
  (( done > total )) && done=$total
  echo $(( done * 100 / total ))
}

fmt_remain() {
  local s=$1
  (( s < 0 )) && s=0
  local d=$(( s / 86400 )) h=$(( (s % 86400) / 3600 )) m=$(( (s % 3600) / 60 ))
  if (( d > 0 ));   then printf '%dd%02dh' "$d" "$h"
  elif (( h > 0 )); then printf '%dh%02dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

bar() {
  local p=$1 width=12
  local f=$(( p * width / 100 ))
  (( f > width )) && f=$width
  (( f < 0 )) && f=0
  local e=$(( width - f ))
  local color
  if   [ "$p" -ge 90 ]; then color="$R"
  elif [ "$p" -ge 75 ]; then color="$O"
  elif [ "$p" -ge 50 ]; then color="$Y"
  else color="$G"; fi
  local fill="" empty=""
  for ((i=0; i<f; i++)); do fill+="█"; done
  for ((i=0; i<e; i++)); do empty+="█"; done
  printf '%s%s%s%s%s' "$color" "$fill" "$TROUGH" "$empty" "$N"
}

# --- segments ---
model_seg="${ACCENT}${B}${model}${N}"
dur_seg="${SEP}${MUTED}${dur_fmt}${N}"

sess_seg=""
if [ "$sess_end_ts" -gt 0 ]; then
  sp=$(pct_elapsed "$sess_start_ts" "$sess_end_ts")
  sr=$(fmt_remain $(( sess_end_ts - now_ts )))
  sess_seg="${SEP}${LABEL}session${N} $(bar "$sp") ${SEPC}↻${N}${FG}${B}${sr}${N}"
fi

week_seg=""
if [ "$week_end_ts" -gt 0 ]; then
  wp=$(pct_elapsed "$week_start_ts" "$week_end_ts")
  wr=$(fmt_remain $(( week_end_ts - now_ts )))
  week_seg="${SEP}${LABEL}week${N} $(bar "$wp") ${SEPC}↻${N}${FG}${B}${wr}${N}"
fi

sonnet_seg=""
if [ "$sonnet_end_ts" -gt 0 ]; then
  snp=$(pct_elapsed "$sonnet_start_ts" "$sonnet_end_ts")
  snr=$(fmt_remain $(( sonnet_end_ts - now_ts )))
  sonnet_seg="${SEP}${PINK}sonnet${N} $(bar "$snp") ${SEPC}↻${N}${FG}${B}${snr}${N}"
fi

# context %
ctx_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  ctx_tokens=$(tail -50 "$transcript" 2>/dev/null | \
    jq -rs '[.[] | select(.message.usage) | .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)] | max // 0' 2>/dev/null)
  if [ -n "$ctx_tokens" ] && [ "$ctx_tokens" != "null" ] && [ "$ctx_tokens" -gt 0 ]; then
    if [ "$over200k" = "true" ]; then ctx_max=1000000; else ctx_max=200000; fi
    ctx_pct=$(( ctx_tokens * 100 / ctx_max ))
    if [ "$ctx_pct" -ge 80 ]; then cc="$R"
    elif [ "$ctx_pct" -ge 50 ]; then cc="$Y"
    else cc="$G"; fi
    ctx_seg="${SEP}${MUTED}ctx${N} ${cc}${ctx_pct}%${N}"
  fi
fi
[ -z "$ctx_seg" ] && [ "$over200k" = "true" ] && ctx_seg="${SEP}${R}ctx >200k${N}"

if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
  lines_seg="${SEP}${G}+${added}${N} ${R}-${removed}${N}"
else
  lines_seg=""
fi

style_seg=""
[ -n "$style" ] && [ "$style" != "default" ] && style_seg="${SEP}${MUTED}${style}${N}"

printf '%s%s%s%s%s%s%s%s' \
  "$model_seg" "$dur_seg" \
  "$sess_seg" "$week_seg" "$sonnet_seg" \
  "$ctx_seg" "$lines_seg" "$style_seg"
